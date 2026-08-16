/// <reference path="../pb_data/types.d.ts" />

migrate((db) => {
  const collection = new Collection({
    id: "trainings_col",
    name: "trainings",
    type: "base",
    system: false,
    schema: [
      {
        name: "date",
        type: "date",
        required: true,
        options: {},
      },
      {
        name: "overall_rating",
        type: "number",
        required: false,
        options: { min: 1, max: 10 },
      },
      {
        name: "general_comments",
        type: "text",
        required: false,
        options: { max: 2000 },
      },
    ],
    indexes: [
      "CREATE INDEX idx_trainings_date ON trainings (date)",
    ],
    listRule: "",
    viewRule: "",
    createRule: "",
    updateRule: "",
    deleteRule: "",
  });

  return Dao(db).saveCollection(collection);
}, (db) => {
  const dao = new Dao(db);
  const collection = dao.findCollectionByNameOrId("trainings_col");
  return dao.deleteCollection(collection);
});
