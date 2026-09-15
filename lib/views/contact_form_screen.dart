import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/contact.dart';
import '../providers/dialer_provider.dart';
import '../theme/miui_theme.dart';
import '../widgets/miui_avatar.dart';

class ContactFormScreen extends StatefulWidget {
  final Contact? contact;
  final String? initialPhone;

  const ContactFormScreen({super.key, this.contact, this.initialPhone});

  @override
  State<ContactFormScreen> createState() => _ContactFormScreenState();
}

class _ContactFormScreenState extends State<ContactFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;
  late TextEditingController _companyController;
  String _selectedLabel = 'Mobile';
  int _selectedColorValue = 0xFF0C84FF;

  static const List<int> _colorOptions = [
    0xFF0C84FF,
    0xFF25D366,
    0xFFFF3B30,
    0xFFFF9500,
    0xFF9C27B0,
    0xFF00C6FF,
    0xFF4CAF50,
    0xFFE91E63,
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.contact?.name ?? '');
    _phoneController = TextEditingController(text: widget.contact?.phoneNumber ?? widget.initialPhone ?? '');
    _emailController = TextEditingController(text: widget.contact?.email ?? '');
    _companyController = TextEditingController(text: widget.contact?.company ?? '');
    if (widget.contact != null) {
      _selectedLabel = widget.contact!.label;
      _selectedColorValue = widget.contact!.avatarColorValue;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _companyController.dispose();
    super.dispose();
  }

  void _saveContact() {
    if (_formKey.currentState!.validate()) {
      final provider = Provider.of<DialerProvider>(context, listen: false);

      if (widget.contact != null) {
        final updated = widget.contact!.copyWith(
          name: _nameController.text.trim(),
          phoneNumber: _phoneController.text.trim(),
          email: _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
          company: _companyController.text.trim().isEmpty ? null : _companyController.text.trim(),
          label: _selectedLabel,
          avatarColorValue: _selectedColorValue,
        );
        provider.updateContact(updated);
      } else {
        final newContact = Contact(
          id: 'c_${DateTime.now().millisecondsSinceEpoch}',
          name: _nameController.text.trim(),
          phoneNumber: _phoneController.text.trim(),
          email: _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
          company: _companyController.text.trim().isEmpty ? null : _companyController.text.trim(),
          label: _selectedLabel,
          avatarColorValue: _selectedColorValue,
        );
        provider.addContact(newContact);
      }

      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.contact != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Contact' : 'Create Contact',
            style: const TextStyle(fontFamily: MiuiTheme.fontFamily)),
        actions: [
          IconButton(
            icon: const Icon(Icons.check, color: MiuiColors.callGreen, size: 28),
            onPressed: _saveContact,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Avatar Preview & Color Selector
              Center(
                child: Column(
                  children: [
                    MiuiAvatar(
                      name: _nameController.text.isNotEmpty ? _nameController.text : 'New',
                      colorValue: _selectedColorValue,
                      radius: 40,
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 40,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        shrinkWrap: true,
                        itemCount: _colorOptions.length,
                        itemBuilder: (ctx, i) {
                          final cVal = _colorOptions[i];
                          final isSel = cVal == _selectedColorValue;
                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedColorValue = cVal;
                              });
                            },
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: Color(cVal),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isSel ? Colors.white : Colors.transparent,
                                  width: 2.5,
                                ),
                              ),
                              child: isSel ? const Icon(Icons.check, size: 16, color: Colors.white) : null,
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Name Field
              TextFormField(
                controller: _nameController,
                style: const TextStyle(fontFamily: MiuiTheme.fontFamily),
                decoration: const InputDecoration(
                  labelText: 'Full Name',
                  prefixIcon: Icon(Icons.person_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(14))),
                ),
                validator: (val) => val == null || val.trim().isEmpty ? 'Please enter a name' : null,
                onChanged: (_) => setState(() {}),
              ),

              const SizedBox(height: 16),

              // Phone Number Field
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                style: const TextStyle(fontFamily: MiuiTheme.fontFamily),
                decoration: const InputDecoration(
                  labelText: 'Phone Number',
                  prefixIcon: Icon(Icons.phone_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(14))),
                ),
                validator: (val) =>
                    val == null || val.trim().isEmpty ? 'Please enter a phone number' : null,
              ),

              const SizedBox(height: 16),

              // Company Field
              TextFormField(
                controller: _companyController,
                style: const TextStyle(fontFamily: MiuiTheme.fontFamily),
                decoration: const InputDecoration(
                  labelText: 'Company / Organization',
                  prefixIcon: Icon(Icons.business_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(14))),
                ),
              ),

              const SizedBox(height: 16),

              // Email Field
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                style: const TextStyle(fontFamily: MiuiTheme.fontFamily),
                decoration: const InputDecoration(
                  labelText: 'Email Address',
                  prefixIcon: Icon(Icons.email_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(14))),
                ),
              ),

              const SizedBox(height: 16),

              // Label Dropdown
              DropdownButtonFormField<String>(
                initialValue: _selectedLabel,
                decoration: const InputDecoration(
                  labelText: 'Label',
                  prefixIcon: Icon(Icons.label_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(14))),
                ),
                items: ['Mobile', 'Work', 'Home', 'Main', 'Other']
                    .map((l) => DropdownMenuItem(value: l, child: Text(l)))
                    .toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedLabel = val);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
