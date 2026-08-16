/// <reference path="../pb_data/types.d.ts" />

migrate((db) => {
  const collection = new Collection({
    id: "player_competencies_col",
    name: "player_competencies",
    type: "base",
    system: false,
    schema: [
      {
        name: "player",
        type: "relation",
        required: true,
        options: {
          collectionId: "players_col",
          cascadeDelete: true,
          maxSelect: 1,
          minSelect: 1,
        },
      },
      {
        name: "competency",
        type: "relation",
        required: true,
        options: {
          collectionId: "competencies_col",
          cascadeDelete: false,
          maxSelect: 1,
          minSelect: 1,
        },
      },
      {
        name: "rating",
        type: "number",
        required: true,
        options: { min: 1, max: 10 },
      },
      {
        name: "date",
        type: "date",
        required: true,
        options: {},
      },
      {
        name: "notes",
        type: "text",
        required: false,
        options: { max: 1000 },
      },
    ],
    indexes: [
      "CREATE INDEX idx_pc_player ON player_competencies (player)",
      "CREATE INDEX idx_pc_competency ON player_competencies (competency)",
      "CREATE INDEX idx_pc_date ON player_competencies (date)",
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
  const collection = dao.findCollectionByNameOrId("player_competencies_col");
  return dao.deleteCollection(collection);
});
