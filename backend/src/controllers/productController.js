const Product = require('../models/Product');

// Path gambar yang disimpan server (mis. /uploads/products/x.png)
const storedImage = (req, fallback) => {
  if (req.file) {
    return `/uploads/products/${req.file.filename}`;
  }
  return fallback;
};

// @desc    Get all products (dengan pencarian opsional)
// @route   GET /api/products?search=&category=
// @access  Private
const getProducts = async (req, res) => {
  try {
    const { search, category } = req.query;
    const filter = {};

    if (search) {
      filter.$or = [
        { name: { $regex: search, $options: 'i' } },
        { sku: { $regex: search, $options: 'i' } },
      ];
    }
    if (category) {
      filter.category = { $regex: category, $options: 'i' };
    }

    const products = await Product.find(filter).sort({ createdAt: -1 });
    res.json({ products });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};

// @desc    Get single product
// @route   GET /api/products/:id
// @access  Private
const getProductById = async (req, res) => {
  try {
    const product = await Product.findById(req.params.id);
    if (!product) {
      return res.status(404).json({ message: 'Produk tidak ditemukan' });
    }
    res.json({ product });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};

// @desc    Create product
// @route   POST /api/products
// @access  Private
const createProduct = async (req, res) => {
  try {
    const { name, sku, price, cost, stock, category } = req.body;

    if (!name || !sku || price === undefined) {
      return res.status(400).json({ message: 'Nama, SKU, dan harga wajib diisi' });
    }

    const skuExists = await Product.findOne({ sku: sku.toUpperCase() });
    if (skuExists) {
      return res.status(400).json({ message: `SKU "${sku}" sudah digunakan` });
    }

    const product = await Product.create({
      name,
      sku,
      price,
      cost: cost || 0,
      stock: stock || 0,
      category: category || 'Umum',
      image: storedImage(req, ''),
    });

    res.status(201).json({ message: 'Produk berhasil ditambahkan', product });
  } catch (error) {
    if (error.code === 11000) {
      return res.status(400).json({ message: 'SKU sudah digunakan' });
    }
    res.status(500).json({ message: error.message });
  }
};

// @desc    Update product
// @route   PUT /api/products/:id
// @access  Private
const updateProduct = async (req, res) => {
  try {
    const { name, sku, price, cost, stock, category } = req.body;

    const product = await Product.findById(req.params.id);
    if (!product) {
      return res.status(404).json({ message: 'Produk tidak ditemukan' });
    }

    // Cek duplikat SKU jika diubah
    if (sku && sku.toUpperCase() !== product.sku) {
      const skuExists = await Product.findOne({ sku: sku.toUpperCase() });
      if (skuExists) {
        return res.status(400).json({ message: `SKU "${sku}" sudah digunakan` });
      }
    }

    product.name = name || product.name;
    product.sku = sku ? sku.toUpperCase() : product.sku;
    product.price = price !== undefined ? price : product.price;
    product.cost = cost !== undefined ? cost : product.cost;
    product.stock = stock !== undefined ? stock : product.stock;
    product.category = category || product.category;
    product.image =
      req.file != null
        ? `/uploads/products/${req.file.filename}`
        : req.body.image !== undefined
          ? req.body.image
          : product.image;

    await product.save();
    res.json({ message: 'Produk berhasil diperbarui', product });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};

// @desc    Delete product
// @route   DELETE /api/products/:id
// @access  Private
const deleteProduct = async (req, res) => {
  try {
    const product = await Product.findById(req.params.id);
    if (!product) {
      return res.status(404).json({ message: 'Produk tidak ditemukan' });
    }
    await product.deleteOne();
    res.json({ message: 'Produk berhasil dihapus' });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};

module.exports = { getProducts, getProductById, createProduct, updateProduct, deleteProduct };
