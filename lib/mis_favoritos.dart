import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:helioalquiler/detalle_propiedad.dart';

class MyFavoritesScreen extends StatelessWidget {
  const MyFavoritesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Center(child: Text('Inicia sesión para ver tus favoritos.'));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Mis Favoritos')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('Favoritos')
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
              child: Text('No has agregado propiedades a favoritos.'),
            );
          }

          return ListView.builder(
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final favoriteDoc = snapshot.data!.docs[index];
              final favorite = favoriteDoc.data() as Map<String, dynamic>;

              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance
                    .collection('propiedades')
                    .doc(favorite['idPropiedad'])
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
                  final imageUrl =
                      property['imagenes'] != null &&
                          property['imagenes'].isNotEmpty
                      ? property['imagenes'][0]
                      : 'https://via.placeholder.com/150';

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
                      leading: Image.network(
                        imageUrl,
                        width: 80,
                        height: 80,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return const Icon(
                            Icons.image_not_supported,
                            size: 80,
                          );
                        },
                      ),
                      title: Text(property['titulo'] ?? 'Sin título'),
                      subtitle: Text(
                        'Precio: S/${property['precio']?.toStringAsFixed(2) ?? 'N/A'}',
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
