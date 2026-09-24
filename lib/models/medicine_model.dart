class Medicine {
  final String name;
  final double stripPrice;
  final int stripQuantity;

  Medicine({
    required this.name,
    required this.stripPrice,
    required this.stripQuantity,
  });

  double calculateAmount(int requiredQty) {
    return (stripPrice / stripQuantity) * requiredQty;
  }
}
