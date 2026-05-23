class Product {
  int? id;
  String productCode;
  String name;
  String? mfgDate;
  String? expDate;
  String quantity;
  String? size;
  String? category;
  String? imagePath;
  String? warehouseName;
  String? barcode;
  bool isSynced;

  // Tenant Information
  String groupId;
  String companyId;

  Product({
    this.id,
    required this.productCode,
    required this.name,
    this.mfgDate,
    this.expDate,
    this.quantity = "1",
    this.size,
    this.category = "General",
    this.imagePath,
    this.warehouseName,
    this.barcode,
    this.isSynced = false,
    this.groupId = "lafi_al_harbi_group",
    this.companyId = "bin_awf",
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'productCode': productCode,
      'name': name,
      'mfgDate': mfgDate,
      'expDate': expDate,
      'quantity': quantity,
      'size': size,
      'category': category,
      'imagePath': imagePath,
      'warehouseName': warehouseName,
      'barcode': barcode,
      'isSynced': isSynced ? 1 : 0,
      'groupId': groupId,
      'companyId': companyId,
    };
  }

  factory Product.fromMap(Map<dynamic, dynamic> map) {
    return Product(
      id: map['id'],
      productCode: map['productCode'] ?? "",
      name: map['name'] ?? "Unknown Product",
      mfgDate: map['mfgDate'],
      expDate: map['expDate'],
      quantity: map['quantity'] ?? "1",
      size: map['size'],
      category: map['category'] ?? "General",
      imagePath: map['imagePath'],
      warehouseName: map['warehouseName'],
      barcode: map['barcode'],
      isSynced: map['isSynced'] == 1 || map['isSynced'] == true,
      groupId: map['groupId'] ?? "lafi_al_harbi_group",
      companyId: map['companyId'] ?? "bin_awf",
    );
  }
}
