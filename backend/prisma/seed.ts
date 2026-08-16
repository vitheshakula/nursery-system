// prisma/seed.ts — idempotent dev seed for the rebuilt domain.
import { MovementType, PrismaClient } from '@prisma/client';
import * as bcrypt from 'bcrypt';

const prisma = new PrismaClient();

const CATEGORIES = ['Plants', 'Pots', 'Soil', 'Fertilizers', 'Others'];

async function main() {
  // --- Admin user ---
  const adminPassword = await bcrypt.hash('ChangeMe123!', 10);
  const admin = await prisma.user.upsert({
    where: { email: 'admin@nursery.local' },
    update: {},
    create: {
      name: 'Nursery Admin',
      email: 'admin@nursery.local',
      password: adminPassword,
      role: 'ADMIN',
      active: true,
    },
  });
  console.log(`Admin: ${admin.email} / ChangeMe123!`);

  // --- Categories ---
  for (const name of CATEGORIES) {
    await prisma.category.upsert({ where: { name }, update: {}, create: { name } });
  }
  const plants = await prisma.category.findUniqueOrThrow({ where: { name: 'Plants' } });
  const pots = await prisma.category.findUniqueOrThrow({ where: { name: 'Pots' } });
  console.log(`Categories: ${CATEGORIES.join(', ')}`);

  // --- Sample inventory items (only if catalog is empty) ---
  const itemCount = await prisma.inventoryItem.count();
  if (itemCount === 0) {
    const samples = [
      { name: 'Rose Plant', categoryId: plants.id, unit: 'piece', costPrice: 30, sellingPrice: 50, openingStock: 200 },
      { name: 'Tulsi Plant', categoryId: plants.id, unit: 'piece', costPrice: 15, sellingPrice: 30, openingStock: 150 },
      { name: 'Clay Pot 6in', categoryId: pots.id, unit: 'piece', costPrice: 25, sellingPrice: 45, openingStock: 100 },
    ];
    let seq = 0;
    for (const s of samples) {
      seq += 1;
      const sku = `ITM-${String(seq).padStart(4, '0')}`;
      const item = await prisma.inventoryItem.create({
        data: {
          sku,
          name: s.name,
          categoryId: s.categoryId,
          unit: s.unit,
          costPrice: s.costPrice,
          sellingPrice: s.sellingPrice,
          stock: { create: { quantityOnHand: s.openingStock } },
        },
      });
      await prisma.inventoryMovement.create({
        data: {
          itemId: item.id,
          type: MovementType.INITIAL,
          quantityDelta: s.openingStock,
          balanceAfter: s.openingStock,
          referenceType: 'INITIAL',
          notes: 'Seed opening stock',
        },
      });
    }
    // Keep the Counter consistent with seeded SKUs.
    await prisma.counter.upsert({
      where: { key: 'ITM' },
      update: { value: samples.length },
      create: { key: 'ITM', value: samples.length },
    });
    console.log(`Inventory: ${samples.length} sample items`);
  }

  // --- Sample vendor (only if none exist) ---
  const vendorCount = await prisma.vendor.count();
  if (vendorCount === 0) {
    await prisma.vendor.create({
      data: { vendorCode: 'VEN-0001', name: 'Ramesh Cart', phone: '9000000001' },
    });
    await prisma.counter.upsert({
      where: { key: 'VEN' },
      update: { value: 1 },
      create: { key: 'VEN', value: 1 },
    });
    console.log('Vendor: VEN-0001 Ramesh Cart');
  }
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(() => prisma.$disconnect());
