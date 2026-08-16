/// <reference path="../pb_data/types.d.ts" />

migrate((db) => {
  const collection = new Collection({
    id: "matches_col",
    name: "matches",
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
        name: "opponent",
        type: "text",
        required: true,
        options: { min: 1, max: 200 },
      },
      {
        name: "home_away",
        type: "select",
        required: true,
        options: {
          values: ["home", "away"],
          maxSelect: 1,
        },
      },
      {
        name: "score_team",
        type: "number",
        required: false,
        options: { min: 0, max: 5 },
      },
      {
        name: "score_opponent",
        type: "number",
        required: false,
        options: { min: 0, max: 5 },
      },
      {
        name: "general_notes",
        type: "text",
        required: false,
        options: { max: 2000 },
      },
    ],
    indexes: [
      "CREATE INDEX idx_matches_date ON matches (date)",
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
  const collection = dao.findCollectionByNameOrId("matches_col");
  return dao.deleteCollection(collection);
});
