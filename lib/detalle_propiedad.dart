import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DetallePropiedadScreen extends StatefulWidget {
  final String propertyId;

  const DetallePropiedadScreen({super.key, required this.propertyId});

  @override
  State<DetallePropiedadScreen> createState() => _DetallePropiedadScreenState();
}

class _DetallePropiedadScreenState extends State<DetallePropiedadScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isFavorite = false;

  @override
  void initState() {
    super.initState();
    _checkIfFavorite();
  }

  void _checkIfFavorite() async {
    final user = _auth.currentUser;
    if (user != null) {
      final favoriteDoc = await _firestore
          .collection('Favoritos')
          .where('idUsuario', isEqualTo: user.uid)
          .where('idPropiedad', isEqualTo: widget.propertyId)
          .limit(1)
          .get();
      if (mounted) {
        setState(() {
          _isFavorite = favoriteDoc.docs.isNotEmpty;
        });
      }
    }
  }

  void _toggleFavorite() async {
    final user = _auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Debes iniciar sesión para agregar a favoritos'),
        ),
      );
      return;
    }

    try {
      if (_isFavorite) {
        final favoriteDoc = await _firestore
            .collection('Favoritos')
            .where('idUsuario', isEqualTo: user.uid)
            .where('idPropiedad', isEqualTo: widget.propertyId)
            .limit(1)
            .get();
        if (favoriteDoc.docs.isNotEmpty) {
          await _firestore
              .collection('Favoritos')
              .doc(favoriteDoc.docs.first.id)
              .delete();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Propiedad eliminada de favoritos')),
          );
          setState(() {
            _isFavorite = false;
          });
        }
      } else {
        await _firestore.collection('Favoritos').add({
          'idUsuario': user.uid,
          'idPropiedad': widget.propertyId,
          'fecha': Timestamp.now(),
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Propiedad agregada a favoritos')),
        );
        setState(() {
          _isFavorite = true;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al actualizar favoritos: $e')),
      );
    }
  }

  void _showReservationDialog(BuildContext context) {
    final user = _auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Debes iniciar sesión para reservar')),
      );
      return;
    }

    DateTime? startDate;
    DateTime? endDate;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reservar Propiedad'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Selecciona las fechas de tu reserva.'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () async {
                final selectedDates = await showDateRangePicker(
                  context: context,
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (selectedDates != null) {
                  startDate = selectedDates.start;
                  endDate = selectedDates.end;
                }
              },
              child: const Text('Seleccionar Fechas'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () async {
              if (startDate != null && endDate != null) {
                await _firestore.collection('Reservas').add({
                  'idUsuario': user.uid,
                  'idPropiedad': widget.propertyId,
                  'fechaInicio': startDate,
                  'fechaFin': endDate,
                  'estado': 'pendiente',
                  'fechaReserva': Timestamp.now(),
                });
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Reserva realizada con éxito')),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Por favor, selecciona un rango de fechas'),
                  ),
                );
              }
            },
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
  }

  void _showCommentDialog(BuildContext context) {
    final user = _auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Debes iniciar sesión para comentar')),
      );
      return;
    }

    final TextEditingController commentController = TextEditingController();
    double rating = 3.0;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Comentar y Puntuar'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: commentController,
                decoration: const InputDecoration(
                  hintText: 'Escribe tu comentario...',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              const Text('Puntuación:'),
              StatefulBuilder(
                builder: (context, setDialogState) {
                  return Slider(
                    value: rating,
                    min: 1,
                    max: 5,
                    divisions: 4,
                    label: rating.round().toString(),
                    onChanged: (double value) {
                      setDialogState(() {
                        rating = value;
                      });
                    },
                  );
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () async {
              if (commentController.text.isNotEmpty) {
                await _firestore.collection('Comentarios').add({
                  'idUsuario': user.uid,
                  'idPropiedad': widget.propertyId,
                  'comentario': commentController.text,
                  'puntuacion': rating.round(),
                  'fecha': Timestamp.now(),
                });
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Comentario publicado con éxito'),
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Por favor, escribe un comentario'),
                  ),
                );
              }
            },
            child: const Text('Publicar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = _auth.currentUser;

    return Scaffold(
      appBar: AppBar(title: const Text('Detalle de Propiedad')),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('propiedades')
            .doc(widget.propertyId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('Propiedad no encontrada'));
          }

          final property = snapshot.data!.data() as Map<String, dynamic>;
          final imagenes = List<String>.from(property['imagenes'] ?? []);
          final servicios = List<String>.from(property['servicios'] ?? []);
          final isMyProperty = currentUser?.uid == property['idUsuario'];

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Galería de imágenes
                SizedBox(
                  height: 250,
                  child: PageView.builder(
                    itemCount: imagenes.length,
                    itemBuilder: (context, index) {
                      return Image.network(
                        imagenes[index],
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return const Center(
                            child: Icon(Icons.image_not_supported),
                          );
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  property['titulo'] ?? 'Sin título',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'S/.${property['precio']?.toString() ?? 'N/A'}',
                  style: const TextStyle(
                    fontSize: 20,
                    color: Colors.blueAccent,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  property['direccion'] ?? 'Sin dirección',
                  style: const TextStyle(fontSize: 16, color: Colors.grey),
                ),
                const SizedBox(height: 16),
                // Información del propietario
                _buildOwnerInfo(property['idUsuario']),
                const SizedBox(height: 16),
                const Text(
                  'Descripción',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  property['descripcion'] ?? 'Sin descripción',
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Servicios',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8.0,
                  runSpacing: 4.0,
                  children: servicios
                      .map(
                        (servicio) => Chip(
                          label: Text(servicio),
                          backgroundColor: Colors.blue[50],
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 32),
                // Botones de acción
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    IconButton(
                      icon: Icon(
                        _isFavorite ? Icons.favorite : Icons.favorite_border,
                        size: 40,
                        color: _isFavorite ? Colors.red : null,
                      ),
                      onPressed: isMyProperty ? null : _toggleFavorite,
                    ),
                    IconButton(
                      icon: const Icon(Icons.bookmark_add, size: 40),
                      onPressed: isMyProperty
                          ? null
                          : () => _showReservationDialog(context),
                    ),
                    IconButton(
                      icon: const Icon(Icons.comment, size: 40),
                      onPressed: () => _showCommentDialog(context),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Sección de Comentarios
                _buildCommentsSection(),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildOwnerInfo(String ownerId) {
    return FutureBuilder<DocumentSnapshot>(
      future: _firestore.collection('usuarios').doc(ownerId).get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Text('Cargando propietario...');
        }
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const Text('Propietario no encontrado');
        }
        final owner = snapshot.data!.data() as Map<String, dynamic>;
        return Row(
          children: [
            CircleAvatar(
              backgroundImage: owner['fotoPerfilUrl'] != null
                  ? NetworkImage(owner['fotoPerfilUrl'])
                  : null,
              child: owner['fotoPerfilUrl'] == null
                  ? const Icon(Icons.person)
                  : null,
            ),
            const SizedBox(width: 8),
            Text(
              'Publicado por: ${owner['nombre'] ?? 'N/A'}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCommentsSection() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('Comentarios')
          .where('idPropiedad', isEqualTo: widget.propertyId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final comments = snapshot.data?.docs ?? [];
        if (comments.isEmpty) {
          return const Text('No hay comentarios para esta propiedad.');
        }

        double totalRating = 0;
        for (var comment in comments) {
          totalRating += comment['puntuacion'];
        }
        double averageRating = totalRating / comments.length;

        return ExpansionTile(
          title: Text(
            'Comentarios (${comments.length})',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.star, color: Colors.amber, size: 20),
              Text(
                averageRating.toStringAsFixed(1),
                style: const TextStyle(fontSize: 16),
              ),
            ],
          ),
          children: comments.map((comment) {
            final commentData = comment.data() as Map<String, dynamic>;
            final userId = commentData['idUsuario'];

            return FutureBuilder<DocumentSnapshot>(
              future: _firestore.collection('usuarios').doc(userId).get(),
              builder: (context, userSnapshot) {
                if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
                  return const ListTile(title: Text('Usuario desconocido'));
                }
                final userData =
                    userSnapshot.data!.data() as Map<String, dynamic>;
                final userName = userData['nombre'] ?? 'Anónimo';
                final userPhotoUrl = userData['fotoPerfilUrl'] ?? '';

                return ListTile(
                  leading: CircleAvatar(
                    backgroundImage: userPhotoUrl.isNotEmpty
                        ? NetworkImage(userPhotoUrl)
                        : null,
                    child: userPhotoUrl.isEmpty
                        ? const Icon(Icons.person)
                        : null,
                  ),
                  title: Text(
                    userName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(commentData['comentario'] ?? ''),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(commentData['puntuacion'].toString()),
                      const Icon(Icons.star, color: Colors.amber, size: 16),
                    ],
                  ),
                );
              },
            );
          }).toList(),
        );
      },
    );
  }
}

extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${substring(1).toLowerCase()}";
  }
}
