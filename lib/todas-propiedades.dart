import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:helioalquiler/detalle_propiedad.dart';

class PropertySearchScreen extends StatefulWidget {
  const PropertySearchScreen({super.key});

  @override
  State<PropertySearchScreen> createState() => _PropertySearchScreenState();
}

class _PropertySearchScreenState extends State<PropertySearchScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String _searchQuery = '';
  String _selectedType = 'todos';
  String _selectedStatus = 'disponible';
  double _minPrice = 0;
  double _maxPrice = 5000;
  bool _isGridView = false;
  bool _isLoading = false;

  final List<String> _propertyTypes = [
    'todos',
    'departamento',
    'habitacion',
    'casa',
    'oficina',
  ];

  final List<String> _propertyStatuses = [
    'disponible',
    'reservado',
    'alquilado',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Buscar Propiedades'),
        actions: [
          IconButton(
            icon: Icon(_isGridView ? Icons.list : Icons.grid_view),
            onPressed: () {
              setState(() {
                _isGridView = !_isGridView;
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFiltersSection(),
          Expanded(child: _buildPropertiesList()),
        ],
      ),
    );
  }

  Widget _buildFiltersSection() {
    return Card(
      margin: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            TextField(
              decoration: InputDecoration(
                labelText: 'Buscar',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          setState(() {
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
                border: const OutlineInputBorder(),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.toLowerCase();
                });
              },
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedType,
                    items: _propertyTypes.map((type) {
                      return DropdownMenuItem(
                        value: type,
                        child: Text(
                          type == 'todos'
                              ? 'Todos los tipos'
                              : type.capitalize(),
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _selectedType = value;
                        });
                      }
                    },
                    decoration: const InputDecoration(
                      labelText: 'Tipo',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedStatus,
                    items: _propertyStatuses.map((status) {
                      return DropdownMenuItem(
                        value: status,
                        child: Text(status.capitalize()),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _selectedStatus = value;
                        });
                      }
                    },
                    decoration: const InputDecoration(
                      labelText: 'Estado',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Rango de precios:'),
                RangeSlider(
                  values: RangeValues(_minPrice, _maxPrice),
                  min: 0,
                  max: 5000,
                  divisions: 10,
                  labels: RangeLabels(
                    'S/ ${_minPrice.toInt()}',
                    'S/ ${_maxPrice.toInt()}',
                  ),
                  onChanged: (values) {
                    setState(() {
                      _minPrice = values.start;
                      _maxPrice = values.end;
                    });
                  },
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('S/ ${_minPrice.toInt()}'),
                    Text('S/ ${_maxPrice.toInt()}'),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPropertiesList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _getFilteredProperties(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('No se encontraron propiedades'));
        }

        final properties = snapshot.data!.docs;

        if (_isGridView) {
          return GridView.builder(
            padding: const EdgeInsets.all(8),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.8,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: properties.length,
            itemBuilder: (context, index) {
              return _buildPropertyItem(properties[index], true);
            },
          );
        } else {
          return ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: properties.length,
            itemBuilder: (context, index) {
              return _buildPropertyItem(properties[index], false);
            },
          );
        }
      },
    );
  }

  Stream<QuerySnapshot> _getFilteredProperties() {
    Query query = _firestore.collection('propiedades');

    // Filtro por estado
    if (_selectedStatus != 'todos') {
      query = query.where('estado', isEqualTo: _selectedStatus);
    }

    // Filtro por tipo
    if (_selectedType != 'todos') {
      query = query.where('tipo', isEqualTo: _selectedType);
    }

    // Filtro por rango de precios
    query = query.where('precio', isGreaterThanOrEqualTo: _minPrice);
    query = query.where('precio', isLessThanOrEqualTo: _maxPrice);

    // Filtro por búsqueda de texto (en título o dirección)
    if (_searchQuery.isNotEmpty) {
      query = query
          .where('titulo', isGreaterThanOrEqualTo: _searchQuery)
          .where('titulo', isLessThanOrEqualTo: '$_searchQuery\uf8ff');
    }

    return query.snapshots();
  }

  Widget _buildPropertyItem(DocumentSnapshot propertyDoc, bool isGrid) {
    final property = propertyDoc.data() as Map<String, dynamic>;
    final firstImage =
        property['imagenes'] != null && property['imagenes'].isNotEmpty
        ? property['imagenes'][0]
        : null;

    if (isGrid) {
      return Card(
        child: InkWell(
          onTap: () {
            _navigateToPropertyDetail(context, propertyDoc.id);
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: firstImage != null
                    ? Image.network(
                        firstImage,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return const Center(child: Icon(Icons.home));
                        },
                      )
                    : const Center(child: Icon(Icons.home, size: 50)),
              ),
              Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      property['titulo'] ?? 'Sin título',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'S/ ${property['precio']?.toStringAsFixed(2) ?? '0'}',
                      style: const TextStyle(
                        color: Colors.blue,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.location_on,
                          size: 14,
                          color: Colors.grey[600],
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            property['direccion'] ?? 'Sin dirección',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Chip(
                      label: Text(
                        property['tipo']?.toString().capitalize() ?? 'Sin tipo',
                        style: const TextStyle(fontSize: 12),
                      ),
                      backgroundColor: Colors.grey[200],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      return Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: InkWell(
          onTap: () {
            _navigateToPropertyDetail(context, propertyDoc.id);
          },
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(4),
                    bottomLeft: Radius.circular(4),
                  ),
                  image: firstImage != null
                      ? DecorationImage(
                          image: NetworkImage(firstImage),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: firstImage == null
                    ? const Center(child: Icon(Icons.home, size: 40))
                    : null,
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        property['titulo'] ?? 'Sin título',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'S/ ${property['precio']?.toStringAsFixed(2) ?? '0'}',
                        style: const TextStyle(
                          color: Colors.blue,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.location_on,
                            size: 16,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              property['direccion'] ?? 'Sin dirección',
                              style: TextStyle(color: Colors.grey[600]),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 4,
                        children: [
                          Chip(
                            label: Text(
                              property['tipo']?.toString().capitalize() ??
                                  'Sin tipo',
                              style: const TextStyle(fontSize: 12),
                            ),
                            backgroundColor: Colors.grey[200],
                          ),
                          Chip(
                            label: Text(
                              property['estado']?.toString().capitalize() ??
                                  'Sin estado',
                              style: const TextStyle(fontSize: 12),
                            ),
                            backgroundColor: _getStatusColor(
                              property['estado'],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
  }
}

Color? _getStatusColor(String? status) {
  switch (status) {
    case 'disponible':
      return Colors.green[100];
    case 'reservado':
      return Colors.orange[100];
    case 'alquilado':
      return Colors.red[100];
    default:
      return Colors.grey[200];
  }
}

void _navigateToPropertyDetail(BuildContext context, String propertyId) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => DetallePropiedadScreen(propertyId: propertyId),
    ),
  );
}
