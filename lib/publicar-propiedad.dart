import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:helioalquiler/detalle_propiedad.dart';

// La pantalla principal ahora maneja el TabController
class PublishPropertyScreen extends StatefulWidget {
  const PublishPropertyScreen({super.key});

  @override
  State<PublishPropertyScreen> createState() => _PublishPropertyScreenState();
}

class _PublishPropertyScreenState extends State<PublishPropertyScreen> {
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Gestionar Propiedades'),
          bottom: TabBar(
            indicatorColor: Theme.of(context).colorScheme.onPrimary,
            labelStyle: Theme.of(context).textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onPrimary,
            ),
            unselectedLabelStyle: Theme.of(context).textTheme.bodyLarge
                ?.copyWith(
                  color: Theme.of(
                    context,
                  ).colorScheme.onPrimary.withOpacity(0.7),
                ),
            tabs: const [
              Tab(text: 'Publicar Nueva', icon: Icon(Icons.add_home)),
              Tab(text: 'Mis Propiedades', icon: Icon(Icons.list_alt)),
            ],
          ),
        ),
        body: const TabBarView(
          children: [_PublishNewPropertyTab(), _MyPropertiesTab()],
        ),
      ),
    );
  }
}

// ---------------------------------------------
// Pestaña 1: Formulario para publicar una nueva propiedad
// ---------------------------------------------
class _PublishNewPropertyTab extends StatelessWidget {
  const _PublishNewPropertyTab();

  @override
  Widget build(BuildContext context) {
    return const SingleChildScrollView(
      padding: EdgeInsets.all(24.0),
      child: _PropertyForm(),
    );
  }
}

// ---------------------------------------------
// Pestaña 2: Lista de propiedades publicadas por el usuario actual
// ---------------------------------------------
class _MyPropertiesTab extends StatelessWidget {
  const _MyPropertiesTab();

  void _showDeleteConfirmation(BuildContext context, String propertyId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Propiedad'),
        content: const Text(
          '¿Estás seguro de que quieres eliminar esta propiedad? Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await FirebaseFirestore.instance
                    .collection('propiedades')
                    .doc(propertyId)
                    .delete();
                if (context.mounted) {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Propiedad eliminada con éxito.'),
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error al eliminar: $e')),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  void _showEditPropertyForm(
    BuildContext context,
    DocumentSnapshot propertyDoc,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Editar Propiedad'),
        content: SizedBox(
          width: MediaQuery.of(context).size.width * 0.9,
          child: SingleChildScrollView(
            child: _PropertyForm(propertyToEdit: propertyDoc),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );
  }

  // Nuevo método para aceptar una reserva
  Future<void> _acceptReservation(
    BuildContext context,
    String reservationId,
    String propertyId,
  ) async {
    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final reservationRef = FirebaseFirestore.instance
            .collection('Reservas')
            .doc(reservationId);
        final propertyRef = FirebaseFirestore.instance
            .collection('propiedades')
            .doc(propertyId);

        transaction.update(reservationRef, {'estado': 'aceptada'});
        transaction.update(propertyRef, {'estado': 'reservado'});
      });
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reserva aceptada con éxito.')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al aceptar la reserva: $e')),
        );
      }
    }
  }

  // Nuevo método para rechazar una reserva
  Future<void> _rejectReservation(
    BuildContext context,
    String reservationId,
    String propertyId,
    String reservationState,
  ) async {
    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final reservationRef = FirebaseFirestore.instance
            .collection('Reservas')
            .doc(reservationId);
        final propertyRef = FirebaseFirestore.instance
            .collection('propiedades')
            .doc(propertyId);

        transaction.update(reservationRef, {'estado': 'rechazada'});

        if (reservationState == 'pendiente') {
          // Si la propiedad no tiene otras reservas pendientes,
          // la cambiamos a 'disponible'.
          final pendingReservations = await FirebaseFirestore.instance
              .collection('Reservas')
              .where('idPropiedad', isEqualTo: propertyId)
              .where('estado', isEqualTo: 'pendiente')
              .count()
              .get();

          if (pendingReservations.count == 0) {
            transaction.update(propertyRef, {'estado': 'disponible'});
          }
        }
      });

      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Reserva rechazada.')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al rechazar la reserva: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Center(
        child: Text(
          'Inicia sesión para ver tus propiedades.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('propiedades')
          .where('idUsuario', isEqualTo: user.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Text(
              'No has publicado ninguna propiedad aún.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          );
        }

        final properties = snapshot.data!.docs;

        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: properties.length,
          itemBuilder: (context, index) {
            final propertyDoc = properties[index];
            final data = propertyDoc.data() as Map<String, dynamic>;
            final propertyId = propertyDoc.id;
            final imageUrl =
                data['imagenes'] != null && data['imagenes'].isNotEmpty
                ? data['imagenes'][0]
                : 'https://via.placeholder.com/150';

            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ExpansionTile(
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    imageUrl,
                    width: 60,
                    height: 60,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        width: 60,
                        height: 60,
                        color: Colors.blueGrey[100],
                        child: const Icon(
                          Icons.image_not_supported,
                          size: 30,
                          color: Colors.blueGrey,
                        ),
                      );
                    },
                  ),
                ),
                title: Text(
                  data['titulo'] ?? 'Sin título',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  'Precio: S/.${data['precio'] ?? 'N/A'}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.blue),
                      onPressed: () =>
                          _showEditPropertyForm(context, propertyDoc),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () =>
                          _showDeleteConfirmation(context, propertyId),
                    ),
                  ],
                ),
                children: [
                  // Aquí se mostrarán las reservas pendientes
                  _buildPendingReservations(context, propertyId),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // Nuevo método para construir la lista de reservas pendientes
  Widget _buildPendingReservations(BuildContext context, String propertyId) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('Reservas')
          .where('idPropiedad', isEqualTo: propertyId)
          .where('estado', isEqualTo: 'pendiente')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'No hay reservas pendientes para esta propiedad.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          );
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final reservationDoc = snapshot.data!.docs[index];
            final reservationId = reservationDoc.id;
            final reservationData =
                reservationDoc.data() as Map<String, dynamic>;
            final userId = reservationData['idUsuario'];
            final startDate = (reservationData['fechaInicio'] as Timestamp)
                .toDate();
            final endDate = (reservationData['fechaFin'] as Timestamp).toDate();

            return FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance
                  .collection('usuarios')
                  .doc(userId)
                  .get(),
              builder: (context, userSnapshot) {
                if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
                  return const ListTile(title: Text('Usuario desconocido'));
                }
                final userData =
                    userSnapshot.data!.data() as Map<String, dynamic>;
                final userName = userData['nombre'] ?? 'Anónimo';
                final userPhotoUrl = userData['fotoPerfilUrl'] ?? '';

                return ListTile(
                  tileColor: Colors.blueGrey[50],
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  leading: CircleAvatar(
                    backgroundImage: userPhotoUrl.isNotEmpty
                        ? NetworkImage(userPhotoUrl)
                        : null,
                    child: userPhotoUrl.isEmpty
                        ? const Icon(Icons.person, color: Colors.white)
                        : null,
                    backgroundColor: Colors.blueGrey,
                  ),
                  title: Text(
                    'Reserva de $userName',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  subtitle: Text(
                    'Fechas: ${startDate.toString().substring(0, 10)} - ${endDate.toString().substring(0, 10)}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.check_circle,
                          color: Colors.green,
                        ),
                        onPressed: () => _acceptReservation(
                          context,
                          reservationId,
                          propertyId,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.cancel, color: Colors.red),
                        onPressed: () => _rejectReservation(
                          context,
                          reservationId,
                          propertyId,
                          'pendiente',
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

// ---------------------------------------------
// Formulario de propiedad reutilizable para publicar y editar
// ---------------------------------------------
class _PropertyForm extends StatefulWidget {
  final DocumentSnapshot? propertyToEdit;

  const _PropertyForm({this.propertyToEdit});

  @override
  State<_PropertyForm> createState() => _PropertyFormState();
}

class _PropertyFormState extends State<_PropertyForm> {
  final _formKey = GlobalKey<FormState>();
  final List<TextEditingController> _imageUrlControllers = [];
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _addressController = TextEditingController();
  final _servicesController = TextEditingController();
  String _propertyType = 'departamento';
  String _propertyStatus = 'disponible';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Si se está editando una propiedad, rellenar los campos
    if (widget.propertyToEdit != null) {
      final data = widget.propertyToEdit!.data() as Map<String, dynamic>;
      _titleController.text = data['titulo'] ?? '';
      _descriptionController.text = data['descripcion'] ?? '';
      _priceController.text = data['precio']?.toString() ?? '';
      _addressController.text = data['direccion'] ?? '';
      _propertyType = data['tipo'] ?? 'departamento';
      _propertyStatus = data['estado'] ?? 'disponible';
      _servicesController.text =
          (data['servicios'] as List<dynamic>?)?.join(', ') ?? '';

      final images = data['imagenes'] as List<dynamic>?;
      if (images != null && images.isNotEmpty) {
        for (var url in images) {
          _imageUrlControllers.add(TextEditingController(text: url));
        }
      } else {
        _addImageField();
      }
    } else {
      // Si es un formulario nuevo, solo agregar un campo de imagen vacío
      _addImageField();
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _addressController.dispose();
    _servicesController.dispose();
    for (var controller in _imageUrlControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _addImageField() {
    setState(() {
      _imageUrlControllers.add(TextEditingController());
    });
  }

  void _submitProperty() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Debes iniciar sesión para publicar/editar'),
            ),
          );
        }
        setState(() {
          _isLoading = false;
        });
        return;
      }

      final images = _imageUrlControllers
          .map((controller) => controller.text)
          .where((url) => url.isNotEmpty)
          .toList();
      final services = _servicesController.text
          .split(',')
          .map((s) => s.trim())
          .toList();

      final propertyData = {
        'idUsuario': user.uid,
        'titulo': _titleController.text,
        'descripcion': _descriptionController.text,
        'precio': double.tryParse(_priceController.text) ?? 0,
        'direccion': _addressController.text,
        'tipo': _propertyType,
        'estado': _propertyStatus,
        'servicios': services,
        'imagenes': images,
      };

      try {
        if (widget.propertyToEdit != null) {
          // Editar propiedad existente
          await FirebaseFirestore.instance
              .collection('propiedades')
              .doc(widget.propertyToEdit!.id)
              .update(propertyData);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Propiedad actualizada con éxito!')),
            );
            Navigator.of(context).pop(); // Cerrar el diálogo
          }
        } else {
          // Publicar nueva propiedad
          await FirebaseFirestore.instance.collection('propiedades').add({
            ...propertyData,
            'fechaPublicacion': Timestamp.now(),
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Propiedad publicada con éxito!')),
            );
            // Limpiar los campos después de la publicación
            _titleController.clear();
            _descriptionController.clear();
            _priceController.clear();
            _addressController.clear();
            _servicesController.clear();
            _imageUrlControllers.clear();
            _addImageField();
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al procesar la propiedad: $e')),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  Widget _buildImageUrlField(int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 3), // changes position of shadow
          ),
        ],
      ),
      child: TextFormField(
        controller: _imageUrlControllers[index],
        decoration: InputDecoration(
          labelText: 'URL de Imagen ${index + 1}',
          prefixIcon: const Icon(Icons.image),
          border: InputBorder.none,
          suffixIcon: index > 0
              ? IconButton(
                  icon: const Icon(
                    Icons.remove_circle_outline,
                    color: Colors.red,
                  ),
                  onPressed: () {
                    setState(() {
                      _imageUrlControllers.removeAt(index);
                    });
                  },
                )
              : null,
        ),
        keyboardType: TextInputType.url,
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Por favor ingresa una URL de imagen';
          }
          return null;
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.2),
                    spreadRadius: 1,
                    blurRadius: 5,
                    offset: const Offset(0, 3), // changes position of shadow
                  ),
                ],
              ),
              child: TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Título',
                  prefixIcon: Icon(Icons.title),
                  border: InputBorder.none,
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor ingresa un título';
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.2),
                    spreadRadius: 1,
                    blurRadius: 5,
                    offset: const Offset(0, 3), // changes position of shadow
                  ),
                ],
              ),
              child: TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Descripción',
                  prefixIcon: Icon(Icons.description),
                  border: InputBorder.none,
                ),
                maxLines: 3,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor ingresa una descripción';
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.2),
                    spreadRadius: 1,
                    blurRadius: 5,
                    offset: const Offset(0, 3), // changes position of shadow
                  ),
                ],
              ),
              child: TextFormField(
                controller: _priceController,
                decoration: const InputDecoration(
                  labelText: 'Precio',
                  prefixIcon: Icon(Icons.attach_money),
                  prefixText: 'S/. ',
                  border: InputBorder.none,
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor ingresa un precio';
                  }
                  if (double.tryParse(value) == null) {
                    return 'El precio debe ser un número válido';
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.2),
                    spreadRadius: 1,
                    blurRadius: 5,
                    offset: const Offset(0, 3), // changes position of shadow
                  ),
                ],
              ),
              child: TextFormField(
                controller: _addressController,
                decoration: const InputDecoration(
                  labelText: 'Dirección',
                  prefixIcon: Icon(Icons.location_on),
                  border: InputBorder.none,
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor ingresa una dirección';
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.2),
                    spreadRadius: 1,
                    blurRadius: 5,
                    offset: const Offset(0, 3), // changes position of shadow
                  ),
                ],
              ),
              child: DropdownButtonFormField<String>(
                value: _propertyType,
                decoration: const InputDecoration(
                  labelText: 'Tipo de propiedad',
                  prefixIcon: Icon(Icons.home_work),
                  border: InputBorder.none,
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'departamento',
                    child: Text('Departamento'),
                  ),
                  DropdownMenuItem(
                    value: 'habitacion',
                    child: Text('Habitación'),
                  ),
                  DropdownMenuItem(value: 'casa', child: Text('Casa')),
                  DropdownMenuItem(value: 'oficina', child: Text('Oficina')),
                ],
                onChanged: (newValue) {
                  setState(() {
                    _propertyType = newValue!;
                  });
                },
              ),
            ),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.2),
                    spreadRadius: 1,
                    blurRadius: 5,
                    offset: const Offset(0, 3), // changes position of shadow
                  ),
                ],
              ),
              child: DropdownButtonFormField<String>(
                value: _propertyStatus,
                decoration: const InputDecoration(
                  labelText: 'Estado',
                  prefixIcon: Icon(Icons.info_outline),
                  border: InputBorder.none,
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'disponible',
                    child: Text('Disponible'),
                  ),
                  DropdownMenuItem(
                    value: 'reservado',
                    child: Text('Reservado'),
                  ),
                  DropdownMenuItem(
                    value: 'alquilado',
                    child: Text('Alquilado'),
                  ),
                ],
                onChanged: (newValue) {
                  setState(() {
                    _propertyStatus = newValue!;
                  });
                },
              ),
            ),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.2),
                    spreadRadius: 1,
                    blurRadius: 5,
                    offset: const Offset(0, 3), // changes position of shadow
                  ),
                ],
              ),
              child: TextFormField(
                controller: _servicesController,
                decoration: const InputDecoration(
                  labelText: 'Servicios (separados por coma)',
                  prefixIcon: Icon(Icons.room_service),
                  hintText: 'agua, luz, internet, cable, ...',
                  border: InputBorder.none,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Imágenes de la propiedad',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Ingresa URLs de imágenes (ej: https://ejemplo.com/imagen.jpg)',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            ...List.generate(_imageUrlControllers.length, (index) {
              return _buildImageUrlField(index);
            }),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.add_photo_alternate),
                label: const Text('Agregar otra imagen'),
                onPressed: _addImageField,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.secondary,
                  side: BorderSide(
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submitProperty,
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(
                        widget.propertyToEdit != null
                            ? 'Guardar Cambios'
                            : 'Publicar Propiedad',
                      ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
