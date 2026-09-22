import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../checkout/checkout_pages.dart';
import '../checkout/commerce_api.dart';
import '../store/catalog_api.dart';
import 'admin_api.dart';

class AdminCatalogPage extends StatefulWidget {
  const AdminCatalogPage({super.key, required this.repository});
  final AdminRepository repository;
  @override
  State<AdminCatalogPage> createState() => _AdminCatalogPageState();
}

class _AdminCatalogPageState extends State<AdminCatalogPage> {
  final _search = TextEditingController();
  List<AdminProduct> _products = [];
  bool? _active;
  bool _busy = true, _more = false, _authorized = false;
  String? _error;
  int _generation = 0;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load({bool append = false}) async {
    final generation = ++_generation;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await widget.repository.products(
        search: _search.text.trim(),
        active: _active,
        skip: append ? _products.length : 0,
      );
      if (!mounted || generation != _generation) return;
      setState(() {
        _authorized = true;
        _products = append ? [..._products, ...result] : result;
        _more = result.length == 20;
      });
    } catch (e) {
      if (mounted && generation == _generation) {
        setState(() {
          _error = errorText(e);
          if (e is CommerceException && (e.status == 401 || e.status == 403)) {
            _authorized = false;
            _products = [];
          }
        });
      }
    } finally {
      if (mounted && generation == _generation) setState(() => _busy = false);
    }
  }

  Future<void> _edit([int? id]) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) =>
            AdminProductPage(repository: widget.repository, productId: id),
      ),
    );
    if (saved == true && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Produto salvo.')));
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Administração · Produtos'),
      actions: [
        IconButton(
          tooltip: 'Atualizar produtos',
          onPressed: _busy ? null : () => _load(),
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    floatingActionButton: _authorized
        ? FloatingActionButton.extended(
            onPressed: _busy ? null : () => _edit(),
            icon: const Icon(Icons.add),
            label: const Text('NOVO PRODUTO'),
          )
        : null,
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 100),
              children: [
                Text(
                  'Seu catálogo',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Cuide dos produtos, preços e unidades disponíveis da loja.',
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _search,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _load(),
                  decoration: InputDecoration(
                    labelText: 'Buscar por nome',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: IconButton(
                      tooltip: 'Buscar',
                      onPressed: () => _load(),
                      icon: const Icon(Icons.arrow_forward),
                    ),
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final option in <bool?, String>{
                      null: 'Todos',
                      true: 'Ativos',
                      false: 'Inativos',
                    }.entries)
                      ChoiceChip(
                        label: Text(option.value),
                        selected: _active == option.key,
                        onSelected: _busy
                            ? null
                            : (_) {
                                setState(() => _active = option.key);
                                _load();
                              },
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                if (_busy) const LinearProgressIndicator(),
                if (_error != null) RetryNotice(_error!, () => _load()),
                if (!_busy && _error == null && _products.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Text('Nenhum produto encontrado.'),
                  ),
                for (final item in _products)
                  Card(
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(12),
                      leading: SizedBox(
                        width: 56,
                        height: 64,
                        child: item.imageUrl == null
                            ? const Icon(Icons.inventory_2_outlined)
                            : Image.network(
                                item.imageUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) =>
                                    const Icon(Icons.broken_image_outlined),
                              ),
                      ),
                      title: Text(item.name),
                      subtitle: Text(
                        '${money(item.priceCents)} · ${item.stock} disponíveis\n${item.active ? 'Ativo' : 'Inativo'}${item.categoryName == null ? '' : ' · ${item.categoryName}'}',
                      ),
                      isThreeLine: true,
                      trailing: const Icon(Icons.edit_outlined),
                      onTap: () => _edit(item.id),
                    ),
                  ),
                if (_more && _error == null)
                  OutlinedButton(
                    onPressed: _busy ? null : () => _load(append: true),
                    child: const Text('CARREGAR MAIS'),
                  ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class AdminProductPage extends StatefulWidget {
  const AdminProductPage({super.key, required this.repository, this.productId});
  final AdminRepository repository;
  final int? productId;
  @override
  State<AdminProductPage> createState() => _AdminProductPageState();
}

class _AdminProductPageState extends State<AdminProductPage> {
  final _form = GlobalKey<FormState>();
  final _scroll = ScrollController();
  final _name = TextEditingController(), _description = TextEditingController();
  final _price = TextEditingController(),
      _stock = TextEditingController(text: '0');
  final _image = TextEditingController();
  final _package = {
    for (final entry in AdminProduct.packageDefaults.entries)
      entry.key: TextEditingController(text: '${entry.value}'),
  };
  List<StoreCategory> _categories = [];
  int? _categoryId, _version;
  bool _active = true,
      _loading = true,
      _saving = false,
      _conflict = false,
      _loaded = false;
  String? _error, _preview;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _scroll.dispose();
    for (final controller in [
      _name,
      _description,
      _price,
      _stock,
      _image,
      ..._package.values,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final categories = await widget.repository.categories();
      final item = widget.productId == null
          ? null
          : await widget.repository.product(widget.productId!);
      if (!mounted) return;
      setState(() {
        _categories = categories;
        if (item != null) {
          _name.text = item.name;
          _description.text = item.description ?? '';
          _price.text =
              '${item.priceCents ~/ 100},${(item.priceCents % 100).toString().padLeft(2, '0')}';
          _stock.text = '${item.stock}';
          _image.text = item.imageUrl ?? '';
          _preview = item.imageUrl;
          _categoryId = item.categoryId;
          _active = item.active;
          _version = item.version;
          for (final entry in item.package.entries) {
            _package[entry.key]!.text = '${entry.value}';
          }
        }
        _loaded = true;
        _conflict = false;
      });
    } catch (e) {
      if (mounted) setState(() => _error = errorText(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  int? _cents(String value) {
    final text = value.trim().replaceAll(',', '.');
    if (!RegExp(r'^\d{1,7}(\.\d{1,2})?$').hasMatch(text)) return null;
    final parts = text.split('.');
    final cents =
        int.parse(parts[0]) * 100 +
        (parts.length == 1 ? 0 : int.parse(parts[1].padRight(2, '0')));
    return cents > 0 && cents <= 100000000 ? cents : null;
  }

  String? _imageError(String? value) {
    final text = value!.trim();
    if (text.isEmpty) return null;
    final uri = Uri.tryParse(text);
    return uri == null ||
            uri.scheme != 'https' ||
            uri.host.isEmpty ||
            uri.userInfo.isNotEmpty ||
            text.length > 2048
        ? 'Informe um link HTTPS de imagem, sem usuário ou senha.'
        : null;
  }

  Future<void> _save() async {
    if (_saving || _conflict) return;
    if (!_form.currentState!.validate()) {
      setState(() => _error = 'Revise os campos destacados antes de salvar.');
      _scroll.animateTo(
        0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.repository.save({
        'name': _name.text.trim(),
        'description': _description.text.trim(),
        'price_cents': _cents(_price.text),
        'stock': int.parse(_stock.text),
        'category_id': _categoryId,
        'image_url': _image.text.trim().isEmpty ? null : _image.text.trim(),
        'is_active': _active,
        for (final entry in _package.entries)
          entry.key: int.parse(entry.value.text),
        if (_version != null) 'version': _version,
      }, id: widget.productId);
      if (mounted) {
        setState(() => _saving = false);
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = errorText(e);
          _conflict = e is CommerceException && e.status == 409;
        });
        _scroll.animateTo(
          0,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _addCategory() async {
    final result = await showDialog<StoreCategory>(
      context: context,
      builder: (_) => _CategoryDialog(repository: widget.repository),
    );
    if (result != null && mounted) {
      setState(() {
        _categories = [..._categories, result];
        _categoryId = result.id;
      });
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: Scaffold(
      appBar: AppBar(
        title: Text(
          widget.productId == null ? 'Novo produto' : 'Editar produto',
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 700),
            child: Form(
              key: _form,
              child: SingleChildScrollView(
                controller: _scroll,
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_loading) const LinearProgressIndicator(),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Text(
                          _error!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    if (_conflict || (!_loaded && !_loading))
                      OutlinedButton(
                        onPressed: _loading ? null : _load,
                        child: Text(
                          _conflict ? 'RECARREGAR DADOS' : 'TENTAR NOVAMENTE',
                        ),
                      ),
                    if (_loaded) ...[
                      TextFormField(
                        key: const ValueKey('admin-name'),
                        controller: _name,
                        enabled: !_saving && !_loading,
                        maxLength: 150,
                        decoration: const InputDecoration(
                          labelText: 'Nome do produto',
                        ),
                        validator: (v) =>
                            v!.trim().isEmpty ? 'Informe o nome.' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        key: const ValueKey('admin-description'),
                        controller: _description,
                        enabled: !_saving && !_loading,
                        maxLines: 3,
                        maxLength: 500,
                        decoration: const InputDecoration(
                          labelText: 'Descrição',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        key: const ValueKey('admin-price'),
                        controller: _price,
                        enabled: !_saving && !_loading,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Preço (R\$)',
                          hintText: '129,90',
                        ),
                        validator: (v) => _cents(v!) == null
                            ? 'Informe um preço positivo com até duas casas decimais.'
                            : null,
                      ),
                      const SizedBox(height: 18),
                      TextFormField(
                        key: const ValueKey('admin-stock'),
                        controller: _stock,
                        enabled: !_saving && !_loading,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Estoque disponível',
                          helperText: 'Unidades disponíveis para novas compras. Reservas já foram descontadas.',
                          helperMaxLines: 2,
                        ),
                        validator: (v) {
                          final n = int.tryParse(v!);
                          return n == null || n < 0 || n > 1000000
                              ? 'Informe de 0 a 1.000.000 unidades.'
                              : null;
                        },
                      ),
                      const SizedBox(height: 24),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<int>(
                              key: ValueKey('admin-category-$_categoryId'),
                              initialValue: _categoryId ?? 0,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'Categoria',
                              ),
                              items: [
                                const DropdownMenuItem(
                                  value: 0,
                                  child: Text('Sem categoria'),
                                ),
                                for (final c in _categories)
                                  DropdownMenuItem(
                                    value: c.id,
                                    child: Text(
                                      c.name,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                              ],
                              onChanged: _saving || _loading
                                  ? null
                                  : (v) => setState(
                                      () => _categoryId = v == 0 ? null : v,
                                    ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Nova categoria',
                            onPressed: _saving || _loading
                                ? null
                                : _addCategory,
                            icon: const Icon(Icons.add),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      TextFormField(
                        key: const ValueKey('admin-image'),
                        controller: _image,
                        enabled: !_saving && !_loading,
                        keyboardType: TextInputType.url,
                        maxLength: 2048,
                        decoration: const InputDecoration(
                          labelText: 'Link da foto (HTTPS)',
                          helperText: 'Use o endereço público da imagem. Deixe vazio para remover.',
                          helperMaxLines: 2,
                        ),
                        validator: _imageError,
                      ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: _saving
                              ? null
                              : () {
                                  if (_imageError(_image.text) == null) {
                                    setState(
                                      () => _preview = _image.text.trim(),
                                    );
                                  }
                                },
                          icon: const Icon(Icons.image_outlined),
                          label: const Text('VER FOTO'),
                        ),
                      ),
                      if (_preview != null && _preview!.isNotEmpty)
                        Image.network(
                          _preview!,
                          height: 180,
                          fit: BoxFit.contain,
                          errorBuilder: (_, _, _) => const SizedBox(
                            height: 80,
                            child: Center(
                              child: Text(
                                'Não foi possível carregar essa imagem.',
                              ),
                            ),
                          ),
                        ),
                      const SizedBox(height: 16),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Produto ativo'),
                        subtitle: const Text(
                          'Produtos inativos ficam ocultos na loja. Pedidos anteriores são preservados.',
                        ),
                        value: _active,
                        onChanged: _saving || _loading
                            ? null
                            : (v) => setState(() => _active = v),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Embalagem para entrega',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Informe peso e medidas por unidade, incluindo a embalagem. Os padrões iniciais devem ser conferidos antes da postagem.',
                      ),
                      const SizedBox(height: 12),
                      for (final entry in const {
                        'weight_grams': 'Peso embalado (gramas)',
                        'height_cm': 'Altura (cm)',
                        'width_cm': 'Largura (cm)',
                        'length_cm': 'Comprimento (cm)',
                      }.entries)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: TextFormField(
                            key: ValueKey('admin-${entry.key}'),
                            controller: _package[entry.key],
                            enabled: !_saving && !_loading,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(labelText: entry.value),
                            validator: (value) {
                              final number = int.tryParse(value ?? '');
                              final max = entry.key == 'weight_grams'
                                  ? 30000
                                  : 100;
                              return number == null ||
                                      number < 1 ||
                                      number > max
                                  ? 'Informe um inteiro entre 1 e $max.'
                                  : null;
                            },
                          ),
                        ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: _saving || _loading || _conflict
                            ? null
                            : _save,
                        icon: _saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.check),
                        label: Text(_saving ? 'SALVANDO...' : 'SALVAR PRODUTO'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _CategoryDialog extends StatefulWidget {
  const _CategoryDialog({required this.repository});
  final AdminRepository repository;
  @override
  State<_CategoryDialog> createState() => _CategoryDialogState();
}

class _CategoryDialogState extends State<_CategoryDialog> {
  final _name = TextEditingController();
  bool _busy = false;
  String? _error;
  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      setState(() => _error = 'Informe o nome da categoria.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await widget.repository.createCategory(_name.text.trim());
      if (mounted) {
        setState(() => _busy = false);
        Navigator.pop(context, result);
      }
    } catch (e) {
      if (mounted) setState(() => _error = errorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: AlertDialog(
      title: const Text('Nova categoria'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _name,
            maxLength: 100,
            enabled: !_busy,
            decoration: InputDecoration(
              labelText: 'Nome',
              errorText: _error,
              errorMaxLines: 3,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('CANCELAR'),
        ),
        FilledButton(
          onPressed: _busy ? null : _save,
          child: Text(_busy ? 'SALVANDO...' : 'CRIAR'),
        ),
      ],
    ),
  );
}
