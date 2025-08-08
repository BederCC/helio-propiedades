import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:helioalquiler/detalle_propiedad.dart';

class MyCommentsScreen extends StatelessWidget {
  const MyCommentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Center(
        child: Text('Inicia sesión para ver tus comentarios.'),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Mis Comentarios')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('Comentarios')
            .where('idUsuario', isEqualTo: user.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text('No tienes comentarios publicados.'),
            );
          }

          return ListView.builder(
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final commentDoc = snapshot.data!.docs[index];
              final comment = commentDoc.data() as Map<String, dynamic>;

              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance
                    .collection('propiedades')
                    .doc(comment['idPropiedad'])
                    .get(),
                builder: (context, propertySnapshot) {
                  if (propertySnapshot.connectionState ==
                      ConnectionState.waiting) {
                    return const ListTile(title: Text('Cargando...'));
                  }
                  if (propertySnapshot.hasError ||
                      !propertySnapshot.hasData ||
                      !propertySnapshot.data!.exists) {
                    return const ListTile(
                      title: Text('Propiedad no encontrada'),
                    );
                  }

                  final property =
                      propertySnapshot.data!.data() as Map<String, dynamic>;

                  return Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: ListTile(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => DetallePropiedadScreen(
                              propertyId: propertySnapshot.data!.id,
                            ),
                          ),
                        );
                      },
                      title: Text(
                        'Propiedad: ${property['titulo'] ?? 'Sin título'}',
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Comentario: "${comment['comentario'] ?? 'N/A'}"',
                          ),
                          Row(
                            children: [
                              const Icon(
                                Icons.star,
                                color: Colors.amber,
                                size: 16,
                              ),
                              Text(
                                'Puntuación: ${comment['puntuacion'] ?? 'N/A'}',
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
