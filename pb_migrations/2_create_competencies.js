/// <reference path="../pb_data/types.d.ts" />

migrate((db) => {
  const collection = new Collection({
    id: "competencies_col",
    name: "competencies",
    type: "base",
    system: false,
    schema: [
      {
        name: "name",
        type: "text",
        required: true,
        options: { min: 1, max: 100 },
      },
      {
        name: "category",
        type: "select",
        required: false,
        options: {
          values: ["technical", "tactical", "physical", "mental"],
          maxSelect: 1,
        },
      },
      {
        name: "description",
        type: "text",
        required: false,
        options: { max: 500 },
      },
    ],
    indexes: [],
    listRule: "",
    viewRule: "",
    createRule: "",
    updateRule: "",
    deleteRule: "",
  });

  return Dao(db).saveCollection(collection);
}, (db) => {
  const dao = new Dao(db);
  const collection = dao.findCollectionByNameOrId("competencies_col");
  return dao.deleteCollection(collection);
});
