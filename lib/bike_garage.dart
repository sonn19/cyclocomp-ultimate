import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BikeGaragePage extends StatefulWidget {
  const BikeGaragePage({super.key});
  @override
  State<BikeGaragePage> createState() => _BikeGaragePageState();
}

class _BikeGaragePageState extends State<BikeGaragePage> {
  List<Map<String, dynamic>> bikes = [];
  String? selectedId;
  bool loading = true;

  @override
  void initState() { super.initState(); load(); }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final entries = prefs.getStringList('garage_bikes') ?? [];
    if (!mounted) return;
    setState(() {
      bikes = entries.map((e) => Map<String,dynamic>.from(jsonDecode(e) as Map)).toList();
      selectedId = prefs.getString('selected_bike_id');
      loading = false;
    });
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('garage_bikes', bikes.map(jsonEncode).toList());
    if (selectedId == null) {
      await prefs.remove('selected_bike_id');
    } else {
      await prefs.setString('selected_bike_id', selectedId!);
    }
  }

  Future<void> addBike() async {
    final name = TextEditingController();
    final type = TextEditingController(text: 'Road Bike');
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tambah Sepeda'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: name, autofocus: true, maxLength: 50,
              decoration: const InputDecoration(labelText: 'Nama sepeda')),
          TextField(controller: type, maxLength: 30,
              decoration: const InputDecoration(labelText: 'Jenis sepeda')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('BATAL')),
          FilledButton(onPressed: () {
            if (name.text.trim().isEmpty) return;
            Navigator.pop(ctx, {'name':name.text.trim(),'type':type.text.trim()});
          }, child: const Text('SIMPAN')),
        ],
      ),
    );
    name.dispose(); type.dispose();
    if (result == null || !mounted) return;
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    setState(() {
      bikes.add({'id':id,'name':result['name'],'type':result['type'],'km':0.0,'chainKm':0.0});
      selectedId ??= id;
    });
    await save();
  }

  Future<void> addDistance(Map<String, dynamic> bike) async {
    final distance = TextEditingController();
    final meters = await showDialog<double>(context: context, builder: (ctx) => AlertDialog(
      title: Text('Tambah jarak: ${bike['name']}'),
      content: TextField(controller: distance, keyboardType:const TextInputType.numberWithOptions(decimal:true),
        decoration:const InputDecoration(labelText:'Jarak kilometer',hintText:'Contoh: 32.5')),
      actions:[
        TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('BATAL')),
        FilledButton(onPressed:()=>Navigator.pop(ctx,double.tryParse(distance.text.replaceAll(',','.'))),
          child:const Text('TAMBAH')),
      ],
    ));
    distance.dispose();
    if (meters == null || !meters.isFinite || meters <= 0 || meters > 10000 || !mounted) return;
    setState(() {
      bike['km'] = ((bike['km'] as num?) ?? 0).toDouble() + meters;
      bike['chainKm'] = ((bike['chainKm'] as num?) ?? 0).toDouble() + meters;
    });
    await save();
  }

  Future<void> selectBike(String id) async {
    setState(() => selectedId = id);
    await save();
  }

  Future<void> resetChain(Map<String,dynamic> bike) async {
    final yes = await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(
      title:const Text('Rantai sudah diganti?'),
      content:const Text('Kilometer rantai akan direset, tetapi kilometer sepeda tetap tersimpan.'),
      actions:[
        TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('BATAL')),
        FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('YA, RESET')),
      ],
    ));
    if (yes != true || !mounted) return;
    setState(() => bike['chainKm'] = 0.0);
    await save();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor:const Color(0xFF0B1420),
    appBar:AppBar(title:const Text('Bike Garage'),backgroundColor:const Color(0xFF0B1420)),
    floatingActionButton:FloatingActionButton.extended(onPressed:addBike,
      icon:const Icon(Icons.add),label:const Text('Tambah Sepeda')),
    body:loading ? const Center(child:CircularProgressIndicator()) : ListView(
      padding:const EdgeInsets.all(14),children:[
        const Text('Pilih sepeda aktif dan catat kilometernya. Data tersimpan di HP ini.',
          style:TextStyle(color:Colors.white70)),
        const SizedBox(height:12),
        if(bikes.isEmpty) const Card(child:Padding(padding:EdgeInsets.all(20),
          child:Text('Belum ada sepeda. Ketuk Tambah Sepeda.'))),
        for(final bike in bikes) Card(child:Padding(padding:const EdgeInsets.all(12),
          child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            RadioListTile<String>(
              title:Text('${bike['name']}',style:const TextStyle(fontWeight:FontWeight.bold)),
              subtitle:Text('${bike['type']}'),
              value:bike['id'] as String,
              groupValue:selectedId,
              onChanged:(value) { if(value!=null) selectBike(value); },
            ),
            Text('Total: ${((bike['km'] as num?)??0).toStringAsFixed(1)} km'),
            Text('Rantai: ${((bike['chainKm'] as num?)??0).toStringAsFixed(1)} km'),
            Row(children:[
              TextButton.icon(onPressed:()=>addDistance(bike),icon:const Icon(Icons.add_road),
                label:const Text('Tambah KM')),
              TextButton(onPressed:()=>resetChain(bike),child:const Text('Ganti rantai')),
            ]),
          ]),
        )),
        const SizedBox(height:80),
      ],
    ),
  );
}
