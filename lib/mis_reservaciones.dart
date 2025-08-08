import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MyReservationsScreen extends StatelessWidget {
  const MyReservationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Center(child: Text('Inicia sesión para ver tus reservas.'));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Mis Reservas')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('Reservas')
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
            return const Center(child: Text('No tienes reservas.'));
          }

          return ListView.builder(
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final reservationDoc = snapshot.data!.docs[index];
              final reservation = reservationDoc.data() as Map<String, dynamic>;

              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance
                    .collection('propiedades')
                    .doc(reservation['idPropiedad'])
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
                  final startDate = (reservation['fechaInicio'] as Timestamp)
                      .toDate();
                  final endDate = (reservation['fechaFin'] as Timestamp)
                      .toDate();

                  return Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: ListTile(
                      title: Text(property['titulo'] ?? 'Sin título'),
                      subtitle: Text(
                        'Fechas: ${startDate.toString().substring(0, 10)} - ${endDate.toString().substring(0, 10)}\n'
                        'Estado: ${reservation['estado'] ?? 'N/A'}',
                      ),
                      // Puedes agregar un onTap para ver el detalle de la reserva
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
