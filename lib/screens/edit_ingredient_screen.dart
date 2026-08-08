import 'package:flutter/material.dart';
import '../models/ingredient.dart';
import '../models/category.dart';
import '../services/template_service.dart';
import '../services/auth.dart';

// ============================================================================
// EditIngredientScreen
// ----------------------------------------------------------------------------
// A single form screen used for BOTH creating a brand-new ingredient and
// editing an existing one - which mode it's in depends on whether the
// `ingredient` constructor parameter is null (create) or not (edit).
// Sharing one screen for both avoids duplicating the same form twice.
// ============================================================================
class EditIngredientScreen extends StatefulWidget {
  // Existing item to edit; null means "create new" mode.
  final Ingredient? ingredient;

  // The full category tree this ingredient belongs (or will belong) to.
  // We need the *whole* tree, not just one category, because saving has
  // to write the entire template back out (see
  // TemplateService.saveTemplateCategories).
  final List<Category> allCategories;

  // Which template allCategories came from - saving writes back to this
  // exact template, via TemplateService.
  final TemplateFile activeTemplate;

  // When creating a new ingredient, which category to drop it into by
  // default (e.g. "the category the user was browsing when they tapped
  // +"). Ignored when editing an existing ingredient.
  final String? targetCategoryName;

  const EditIngredientScreen({
    super.key,
    this.ingredient,
    required this.allCategories,
    required this.activeTemplate,
    this.targetCategoryName,
  });

  @override
  State<EditIngredientScreen> createState() => _EditIngredientScreenState();
}

class _EditIngredientScreenState extends State<EditIngredientScreen> {
  // Attaches to the Form widget below so we can trigger validation
  // (`_formKey.currentState!.validate()`) from code, e.g. on submit.
  final _formKey = GlobalKey<FormState>();

  // TextEditingControllers hold the live text of each field and let us
  // read/set it from code, independent of what's drawn on screen. `late`
  // because they're created in initState() (they need `widget.ingredient`,
  // which isn't available yet at field-declaration time).
  late TextEditingController _nameController;
  late TextEditingController _producerController;
  late TextEditingController _descriptionController;
  late TextEditingController _bottlesCountController;
  late TextEditingController _tagsController;

  // Separate controller for the password confirmation dialog shown on
  // submit - kept apart from the form fields above since it's not part of
  // the ingredient data itself.
  final TextEditingController _passwordController = TextEditingController();

  // True when editing an existing item, false when creating a new one.
  // Only affects labels/titles ("Add" vs "Update") - the save logic below
  // handles both cases uniformly.
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();

    // If an ingredient was passed in, prefill every field with its current
    // values; otherwise start from empty defaults. The `?? ''` fallback
    // pattern means "use this value if present, else use an empty
    // default" - it's what makes the same constructor call work for both
    // create and edit modes.
    _isEditing = widget.ingredient != null;
    _nameController = TextEditingController(text: widget.ingredient?.name ?? '');
    _producerController = TextEditingController(text: widget.ingredient?.producer ?? '');
    _descriptionController = TextEditingController(text: widget.ingredient?.description ?? '');
    _bottlesCountController = TextEditingController(
      text: widget.ingredient?.bottlesCount.toString() ?? '0',
    );
    _tagsController = TextEditingController(
      text: widget.ingredient?.tags.join(', ') ?? '',
    );
  }

  @override
  void dispose() {
    // Every TextEditingController holds native resources and must be
    // disposed when its widget goes away, or it leaks memory. This is a
    // standard pattern any time a StatefulWidget owns controllers.
    _nameController.dispose();
    _producerController.dispose();
    _descriptionController.dispose();
    _bottlesCountController.dispose();
    _tagsController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // Runs when the user taps the Add/Update button: validates the form,
  // asks for the shared edit password, converts the form's raw text into
  // an Ingredient, updates the in-memory category tree, and finally
  // persists the whole tree back to disk.
  Future<void> _submit() async {
    // Runs each TextFormField's `validator`; stops here if any fail
    // (e.g. the Name field being empty).
    if (!_formKey.currentState!.validate()) return;

    // Require the shared password before allowing any write - a very
    // simple safeguard against accidental edits, not real per-user auth.
    final password = await _showPasswordDialog(context);
    if (password == null) return; // User cancelled the password dialog.

    final isPasswordCorrect = await Auth.checkPassword(password);
    if (!isPasswordCorrect) {
      // `mounted` guards against calling context-dependent APIs after an
      // `await` if the user has since navigated away from this screen.
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Incorrect password!')),
      );
      return;
    }

    // Bottle count needs to be a real, non-negative integer - int.tryParse
    // returns null instead of throwing when the text isn't a valid number
    // (e.g. the user typed letters), which we treat the same as "invalid".
    final bottlesCount = int.tryParse(_bottlesCountController.text);
    if (bottlesCount == null || bottlesCount < 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bottles count must be a non-negative number.')),
      );
      return;
    }

    // Build the actual Ingredient object from whatever the user typed.
    final newIngredient = Ingredient(
      name: _nameController.text.trim(),
      producer: _producerController.text.trim(),
      description: _descriptionController.text.trim(),
      bottlesCount: bottlesCount,
      // The tags field is one comma-separated string in the UI (e.g.
      // "rum, baza, karaibski"); split it into a list, trim stray spaces
      // around each tag, and drop any that end up empty (e.g. from a
      // trailing comma).
      tags: _tagsController.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
    );

    // Weave the new/updated ingredient into a *copy* of the category tree
    // (see _upsertIngredientInTree below for exactly how).
    final updatedCategories = _upsertIngredientInTree(
      widget.allCategories,
      original: widget.ingredient,
      replacement: newIngredient,
      preferredCategoryName: widget.targetCategoryName,
    );

    // Save the entire updated tree back to the active template - this
    // always writes the whole file, there's no partial/incremental save.
    await TemplateService.saveTemplateCategories(widget.activeTemplate, updatedCategories);

    if (!mounted) return;
    // Close this screen and hand the created/updated Ingredient back to
    // whichever screen pushed us, via Navigator.pop's optional result
    // value.
    Navigator.pop(context, newIngredient);
  }

  // Walks the category tree and either updates an existing ingredient in
  // place or inserts a brand-new one, returning a *new* tree rather than
  // mutating the one passed in (consistent with Category being immutable -
  // see Category.copyWith in lib/models/category.dart).
  //
  // Strategy, in order:
  // 1) If editing (original != null): find the category currently holding
  //    it (matched by name + producer, since there's no unique ID yet) and
  //    replace it there.
  // 2) If adding and a preferred category was specified: insert into that
  //    category, wherever it is in the tree.
  // 3) Fallback: if neither of the above found a home for it, insert into
  //    the very first top-level category so the data is never silently
  //    dropped.
  List<Category> _upsertIngredientInTree(
    List<Category> categories, {
    required Ingredient? original,
    required Ingredient replacement,
    required String? preferredCategoryName,
  }) {
    // These flags are shared (captured) across every call to the nested
    // walk() function below, so the whole tree walk agrees on whether a
    // replacement/insertion has already happened - preventing us from,
    // say, inserting the same new ingredient into two different
    // categories that happen to share a name.
    bool replaced = false;
    bool inserted = false;

    // A recursive local function ("closure") that rebuilds one category
    // node - and, by calling itself on each subcategory, the entire
    // subtree beneath it - deciding along the way whether this node is
    // where the replacement/insertion belongs.
    Category walk(Category category) {
      final localIngredients = List<Ingredient>.from(category.ingredients);

      if (original != null) {
        // Look for the ingredient being edited by matching name+producer
        // together, our current (simple) stand-in for a unique ID.
        final index = localIngredients.indexWhere(
          (i) => i.name == original.name && i.producer == original.producer,
        );
        if (index != -1) {
          localIngredients[index] = replacement;
          replaced = true;
        }
      }

      // Recurse into subcategories *before* deciding whether to insert
      // here, so a matching descendant category gets first chance to
      // claim the new ingredient.
      final localSubcategories = category.subcategories.map(walk).toList();

      if (!replaced && !inserted && preferredCategoryName != null && category.name == preferredCategoryName) {
        // Creation flow: this is the category the user was browsing when
        // they tapped "+", so add it here - and only once, thanks to the
        // `inserted` guard.
        localIngredients.add(replacement);
        inserted = true;
      }

      return category.copyWith(
        ingredients: localIngredients,
        subcategories: localSubcategories,
      );
    }

    final updated = categories.map(walk).toList();

    if (!replaced && !inserted && updated.isNotEmpty) {
      // Last-resort insertion: if we somehow didn't find where to put the
      // ingredient (e.g. no preferred category matched), stash it in the
      // very first top-level category rather than silently losing the
      // user's input.
      final first = updated.first;
      final firstIngredients = List<Ingredient>.from(first.ingredients)..add(replacement);
      updated[0] = first.copyWith(ingredients: firstIngredients);
    }

    return updated;
  }

  // Shows a simple password prompt and returns whatever the user typed,
  // or null if they hit Cancel. The actual correctness check happens back
  // in _submit() via Auth.checkPassword().
  Future<String?> _showPasswordDialog(BuildContext context) async {
    _passwordController.clear();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enter Password'),
        content: TextField(
          controller: _passwordController,
          // Masks the input with dots, like a normal password field.
          obscureText: true,
          decoration: const InputDecoration(hintText: 'Password'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            // No result value passed => Navigator.pop returns null,
            // which _submit() treats as "cancelled".
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, _passwordController.text),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Ingredient' : 'Add Ingredient'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          // Wrapping the fields in a Form + attaching _formKey is what
          // makes `_formKey.currentState!.validate()` in _submit() able to
          // run every field's `validator` at once.
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Name'),
                // Required field: reject empty/whitespace-only input.
                validator: (value) => value?.trim().isEmpty ?? true ? 'Required' : null,
              ),
              TextFormField(
                controller: _producerController,
                decoration: const InputDecoration(labelText: 'Producer'),
              ),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(labelText: 'Description'),
              ),
              TextFormField(
                controller: _bottlesCountController,
                decoration: const InputDecoration(labelText: 'Bottles Count'),
                // Shows a numeric keyboard on mobile devices - doesn't by
                // itself stop the user typing non-digits, hence the
                // stricter check in _submit().
                keyboardType: TextInputType.number,
                // Only checks "is something typed" here; the real numeric
                // validation (must parse, must be >= 0) runs in _submit()
                // since it needs to show a different message.
                validator: (value) => value?.trim().isEmpty ?? true ? 'Required' : null,
              ),
              TextFormField(
                controller: _tagsController,
                decoration: const InputDecoration(
                  labelText: 'Tags (comma-separated)',
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _submit,
                child: Text(_isEditing ? 'Update' : 'Add'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
