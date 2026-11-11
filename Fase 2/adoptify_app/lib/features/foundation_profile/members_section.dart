import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/api_client.dart';
import '../../shared/widgets/message_box.dart';
import '../foundations/foundation_service.dart';

// Mismo formato que valida el portal (services/memberForm.ts): hasta 2 decimales, sin negativos
final _amount = RegExp(r'^\d{1,10}([.,]\d{1,2})?$');

// Sección "Socios" del perfil de la fundación (HU-F): registro interno con aporte privado. Marcar un socio como
// público muestra solo su nombre y fecha en "Nuestros socios". No hay cobros: el aporte es solo informativo.
class MembersSection extends StatefulWidget {
  const MembersSection({super.key, required this.service});

  final FoundationService service;

  @override
  State<MembersSection> createState() => _MembersSectionState();
}

class _MembersSectionState extends State<MembersSection> {
  List<Member> _members = const [];
  bool _loading = true;
  String? _loadError;
  String? _notice;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final members = await widget.service.fetchMembers();
      if (!mounted) return;
      setState(() {
        _members = members;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadError = errorMessage(error, 'No pudimos cargar tus socios.');
        _loading = false;
      });
    }
  }

  Future<void> _edit([Member? member]) async {
    final saved = await showModalBottomSheet<Member>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _MemberForm(service: widget.service, member: member),
    );
    if (saved == null || !mounted) return;
    setState(() {
      final index = _members.indexWhere((m) => m.id == saved.id);
      _members = index == -1 ? [saved, ..._members] : ([..._members]..[index] = saved);
      _notice = 'Socio guardado.';
    });
  }

  Future<void> _delete(Member member) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Borrar socio'),
        content: Text('¿Borrar a ${member.name} de tus socios?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Borrar')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await widget.service.deleteMember(member.id);
      if (!mounted) return;
      setState(() {
        _members = [
          for (final m in _members)
            if (m.id != member.id) m,
        ];
        _notice = 'Socio borrado.';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _notice = errorMessage(error, 'No pudimos borrar el socio. Inténtalo nuevamente.'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Socios', style: textTheme.titleLarge),
        const SizedBox(height: AdoptifySpacing.xs),
        Text(
          'Registro interno de quienes donan o apoyan a tu fundación. El aporte es privado: en "Nuestros socios" '
          'solo se muestran el nombre y la fecha de los que marques como públicos. Aquí no se realizan cobros.',
          style: textTheme.bodySmall,
        ),
        const SizedBox(height: AdoptifySpacing.md),
        OutlinedButton.icon(
          onPressed: _loading ? null : () => _edit(),
          icon: const Icon(Icons.person_add_alt_outlined, size: 20),
          label: const Text('Agregar socio'),
        ),
        if (_notice != null) ...[
          const SizedBox(height: AdoptifySpacing.sm),
          Text(_notice!, style: textTheme.bodySmall),
        ],
        const SizedBox(height: AdoptifySpacing.md),
        if (_loading)
          const Center(child: CircularProgressIndicator())
        else if (_loadError != null) ...[
          MessageBox.error(message: _loadError!),
          const SizedBox(height: AdoptifySpacing.sm),
          TextButton(onPressed: _load, child: const Text('Reintentar socios')),
        ] else if (_members.isEmpty)
          const _EmptyMembers()
        else
          for (final member in _members) ...[
            _MemberTile(member: member, onEdit: () => _edit(member), onDelete: () => _delete(member)),
            const SizedBox(height: AdoptifySpacing.sm),
          ],
      ],
    );
  }
}

class _EmptyMembers extends StatelessWidget {
  const _EmptyMembers();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.all(AdoptifySpacing.xl),
      decoration: BoxDecoration(color: colors.muted, borderRadius: BorderRadius.circular(AdoptifyRadius.lg)),
      child: Column(
        children: [
          Icon(Icons.groups_outlined, size: 32, color: colors.placeholder),
          const SizedBox(height: AdoptifySpacing.sm),
          Text('Aún no registras socios', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: AdoptifySpacing.xs),
          Text(
            'Agrega a quienes donan o apoyan a tu fundación. Tú decides cuáles se muestran en tu ficha pública.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _MemberTile extends StatelessWidget {
  const _MemberTile({required this.member, required this.onEdit, required this.onDelete});

  final Member member;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final contribution = member.contribution;
    return Container(
      padding: const EdgeInsets.all(AdoptifySpacing.md),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: colors.border),
        borderRadius: BorderRadius.circular(AdoptifyRadius.lg),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(member.name, style: textTheme.titleMedium),
                const SizedBox(height: AdoptifySpacing.xs),
                Text(
                  'Desde el ${dateToDisplay(member.joinedAt)}${contribution == null ? '' : ' · Aporte \$$contribution'}',
                  style: textTheme.bodySmall,
                ),
                const SizedBox(height: AdoptifySpacing.xs),
                Row(
                  children: [
                    Icon(
                      member.isPublic ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                      size: 15,
                      color: colors.textMuted,
                    ),
                    const SizedBox(width: AdoptifySpacing.xs),
                    Text(member.isPublic ? 'Visible en la ficha pública' : 'Solo interno', style: textTheme.bodySmall),
                  ],
                ),
              ],
            ),
          ),
          IconButton(onPressed: onEdit, icon: const Icon(Icons.edit_outlined), tooltip: 'Editar a ${member.name}'),
          IconButton(onPressed: onDelete, icon: const Icon(Icons.delete_outline), tooltip: 'Borrar a ${member.name}'),
        ],
      ),
    );
  }
}

class _MemberForm extends StatefulWidget {
  const _MemberForm({required this.service, this.member});

  final FoundationService service;
  final Member? member;

  @override
  State<_MemberForm> createState() => _MemberFormState();
}

class _MemberFormState extends State<_MemberForm> {
  late final _name = TextEditingController(text: widget.member?.name ?? '');
  late final _contribution = TextEditingController(text: widget.member?.contribution?.toString() ?? '');
  late DateTime _joinedAt = widget.member?.joinedAt ?? DateTime.now();
  late bool _isPublic = widget.member?.isPublic ?? false;
  String? _nameError;
  String? _contributionError;
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _contribution.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _joinedAt,
      firstDate: DateTime(1990),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _joinedAt = picked);
  }

  Future<void> _save() async {
    final amount = _contribution.text.trim().replaceAll(',', '.');
    final nameError = _name.text.trim().isEmpty ? 'Escribe el nombre del socio.' : null;
    final contributionError = amount.isNotEmpty && !_amount.hasMatch(amount)
        ? 'Usa un monto válido, por ejemplo 15000 (máximo 2 decimales).'
        : null;
    setState(() {
      _nameError = nameError;
      _contributionError = contributionError;
      _error = null;
    });
    if (nameError != null || contributionError != null) return;

    setState(() => _saving = true);
    try {
      final saved = await widget.service.saveMember(
        id: widget.member?.id,
        name: _name.text.trim(),
        contribution: amount.isEmpty ? null : amount,
        joinedAt: _joinedAt,
        isPublic: _isPublic,
      );
      if (mounted) Navigator.pop(context, saved);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = errorMessage(error, 'No pudimos guardar el socio. Inténtalo nuevamente.');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AdoptifySpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.member == null ? 'Agregar socio' : 'Editar socio',
              style: textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AdoptifySpacing.lg),
            TextField(
              controller: _name,
              maxLength: 150,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(labelText: 'Nombre *', errorText: _nameError),
            ),
            const SizedBox(height: AdoptifySpacing.sm),
            TextField(
              controller: _contribution,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Aporte en CLP (opcional)',
                helperText: 'Solo registro interno: no se cobra ni se publica.',
                errorText: _contributionError,
              ),
            ),
            const SizedBox(height: AdoptifySpacing.md),
            OutlinedButton.icon(
              onPressed: _saving ? null : _pickDate,
              icon: const Icon(Icons.event_outlined, size: 20),
              label: Text('Fecha de ingreso: ${dateToDisplay(_joinedAt)}'),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _isPublic,
              onChanged: _saving ? null : (value) => setState(() => _isPublic = value),
              title: const Text('Mostrar en "Nuestros socios"'),
              subtitle: const Text('Se publica solo el nombre y la fecha de ingreso, nunca el aporte.'),
            ),
            if (_error != null) ...[
              MessageBox.error(message: _error!),
              const SizedBox(height: AdoptifySpacing.md),
            ],
            FilledButton(onPressed: _saving ? null : _save, child: Text(_saving ? 'Guardando…' : 'Guardar socio')),
          ],
        ),
      ),
    );
  }
}
