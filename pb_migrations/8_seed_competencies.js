/// <reference path="../pb_data/types.d.ts" />

// Seed default competencies for volleyball
migrate((db) => {
  const dao = new Dao(db);
  const collection = dao.findCollectionByNameOrId("competencies");

  const competencies = [
    { name: "Bovenhands", category: "technical" },
    { name: "Onderhands", category: "technical" },
    { name: "Opslag", category: "technical" },
    { name: "Pass", category: "technical" },
    { name: "Aanval", category: "technical" },
    { name: "Blok", category: "technical" },
    { name: "Verdediging", category: "technical" },
    { name: "Positiespel", category: "tactical" },
    { name: "Communicatie", category: "mental" },
    { name: "Conditie", category: "physical" },
  ];

  for (const comp of competencies) {
    const record = new Record(collection);
    record.set("name", comp.name);
    record.set("category", comp.category);
    dao.saveRecord(record);
  }
}, (db) => {
  // Down migration: remove seeded competencies
  const dao = new Dao(db);
  const records = dao.findRecordsByFilter("competencies", "1=1");
  for (const record of records) {
    dao.deleteRecord(record);
  }
});
