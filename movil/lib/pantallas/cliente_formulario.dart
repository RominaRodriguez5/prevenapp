import 'package:flutter/material.dart';

import '../modelos/cliente.dart';
import '../servicios/api.dart';
import '../tema.dart';

/// Formulario para dar de alta una sociedad nueva o editar una existente.
///
/// Al crear, se rellenan también los datos de su primer centro de trabajo (nº de cliente,
/// CIF y dirección) y se pueden marcar las actividades de su contrato.
/// Devuelve la sociedad guardada al cerrar.
class ClienteFormularioPantalla extends StatefulWidget {
  final Cliente? cliente; // null = cliente nuevo

  const ClienteFormularioPantalla({super.key, this.cliente});

  @override
  State<ClienteFormularioPantalla> createState() => _ClienteFormularioPantallaState();
}

class _ClienteFormularioPantallaState extends State<ClienteFormularioPantalla> {
  final _formulario = GlobalKey<FormState>();
  late final _nombre = TextEditingController(text: widget.cliente?.nombre);
  // Primer centro de trabajo (solo al crear)
  final _centroNombre = TextEditingController();
  final _codigo = TextEditingController();
  final _cif = TextEditingController();
  final _direccion = TextEditingController();
  late final _telefono = TextEditingController(text: widget.cliente?.telefono);
  late final _email = TextEditingController(text: widget.cliente?.email);
  late final _contacto = TextEditingController(text: widget.cliente?.personaContacto);
  late final _notas = TextEditingController(text: widget.cliente?.notas);

  List<TipoActividad> _tipos = [];
  final Set<int> _contrato = {};
  bool _guardando = false;
  String? _error;

  bool get _esNuevo => widget.cliente == null;

  @override
  void initState() {
    super.initState();
    if (_esNuevo) _cargarTipos();
  }

  @override
  void dispose() {
    for (final c in [_nombre, _centroNombre, _codigo, _cif, _direccion, _telefono, _email, _contacto, _notas]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _cargarTipos() async {
    try {
      final lista = await api.get('/tipos-actividad') as List;
      setState(() => _tipos = lista.map((t) => TipoActividad.desdeJson(t as Map<String, dynamic>)).toList());
    } on ApiError catch (e) {
      setState(() => _error = e.mensaje);
    }
  }

  /// Texto vacío → null, para no guardar campos en blanco.
  String? _valor(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();

  Future<void> _guardar() async {
    if (!_formulario.currentState!.validate()) return;
    setState(() {
      _guardando = true;
      _error = null;
    });
    final datos = {
      'nombre': _nombre.text.trim(),
      if (_esNuevo) ...{
        'centro_nombre': _valor(_centroNombre),
        'codigo': _valor(_codigo),
        'cif': _valor(_cif),
        'direccion': _valor(_direccion),
      },
      'telefono': _valor(_telefono),
      'email': _valor(_email),
      'persona_contacto': _valor(_contacto),
      'notas': _valor(_notas),
    };
    try {
      final Map<String, dynamic> respuesta;
      if (_esNuevo) {
        respuesta = await api.post('/clientes', datos) as Map<String, dynamic>;
        // Las actividades del contrato, una a una
        for (final tipoId in _contrato) {
          await api.post('/clientes/${respuesta['id']}/obligatorias', {'tipo_actividad_id': tipoId});
        }
      } else {
        respuesta = await api.patch('/clientes/${widget.cliente!.id}', datos) as Map<String, dynamic>;
      }
      if (!mounted) return;
      Navigator.of(context).pop(Cliente.desdeJson(respuesta));
    } on ApiError catch (e) {
      setState(() => _error = e.mensaje);
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Widget _campo(
    TextEditingController controlador,
    String etiqueta,
    IconData icono, {
    TextInputType? teclado,
    String? Function(String?)? validar,
    int lineas = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: controlador,
        keyboardType: teclado,
        maxLines: lineas,
        textCapitalization: teclado == null ? TextCapitalization.sentences : TextCapitalization.none,
        decoration: InputDecoration(labelText: etiqueta, prefixIcon: Icon(icono)),
        validator: validar,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 84,
        title: Cabecera(sobretitulo: 'Cartera de clientes', titulo: _esNuevo ? 'Nueva sociedad' : 'Editar sociedad'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Form(
            key: _formulario,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                const _Titulo('Sociedad'),
                _campo(
                  _nombre,
                  'Nombre de la sociedad *',
                  Icons.business,
                  validar: (v) => (v == null || v.trim().isEmpty) ? 'El nombre es obligatorio' : null,
                ),
                _campo(_telefono, 'Teléfono', Icons.phone_outlined, teclado: TextInputType.phone),
                _campo(
                  _email,
                  'Email',
                  Icons.alternate_email,
                  teclado: TextInputType.emailAddress,
                  validar: (v) => (v != null && v.trim().isNotEmpty && !v.contains('@')) ? 'El email no es válido' : null,
                ),
                _campo(_contacto, 'Persona de contacto', Icons.person_outline),
                _campo(_notas, 'Notas', Icons.notes, lineas: 3),
                if (_esNuevo) ...[
                  const SizedBox(height: 8),
                  const _Titulo('Primer centro de trabajo'),
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 12),
                    child: Text(
                      'Cada centro es un cliente con su nº, CIF y dirección. Luego puedes añadir más centros.',
                      style: TextStyle(color: Paleta.tintaSuave),
                    ),
                  ),
                  _campo(_centroNombre, 'Nombre del centro (por defecto, "Centro principal")', Icons.store_outlined),
                  _campo(_codigo, 'Nº de cliente', Icons.tag),
                  _campo(_cif, 'CIF / NIF', Icons.badge_outlined),
                  _campo(_direccion, 'Dirección', Icons.place_outlined),
                ],
                if (_esNuevo) ...[
                  const SizedBox(height: 8),
                  const _Titulo('Actividades del contrato'),
                  Text(
                    'Marca las actividades que este centro necesita cada año.',
                    style: TextStyle(color: Paleta.tintaSuave),
                  ),
                  const SizedBox(height: 12),
                  if (_tipos.isEmpty)
                    Text('Cargando tipos de actividad…', style: TextStyle(color: Paleta.tintaSuave))
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final tipo in _tipos)
                          FilterChip(
                            label: Text(tipo.nombre),
                            selected: _contrato.contains(tipo.id),
                            selectedColor: Paleta.lavanda,
                            checkmarkColor: Paleta.naranja,
                            onSelected: (marcado) =>
                                setState(() => marcado ? _contrato.add(tipo.id) : _contrato.remove(tipo.id)),
                          ),
                      ],
                    ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ],
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _guardando ? null : _guardar,
                  child: _guardando
                      ? SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 3, color: Paleta.morado),
                        )
                      : Text(_esNuevo ? 'Guardar sociedad' : 'Guardar cambios'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Titulo extends StatelessWidget {
  final String texto;

  const _Titulo(this.texto);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10, top: 4),
      child: Text(texto, style: estiloSeccion),
    );
  }
}
