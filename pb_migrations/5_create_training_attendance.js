/// <reference path="../pb_data/types.d.ts" />

migrate((db) => {
  const collection = new Collection({
    id: "training_attendance_col",
    name: "training_attendance",
    type: "base",
    system: false,
    schema: [
      {
        name: "training",
        type: "relation",
        required: true,
        options: {
          collectionId: "trainings_col",
          cascadeDelete: true,
          maxSelect: 1,
          minSelect: 1,
        },
      },
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
        name: "status",
        type: "select",
        required: true,
        options: {
          values: ["present", "absent", "sick", "injured"],
          maxSelect: 1,
        },
      },
      {
        name: "player_rating",
        type: "number",
        required: false,
        options: { min: 1, max: 10 },
      },
      {
        name: "player_notes",
        type: "text",
        required: false,
        options: { max: 1000 },
      },
    ],
    indexes: [
      "CREATE INDEX idx_ta_training ON training_attendance (training)",
      "CREATE INDEX idx_ta_player ON training_attendance (player)",
      "CREATE UNIQUE INDEX idx_ta_unique ON training_attendance (training, player)",
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
  const collection = dao.findCollectionByNameOrId("training_attendance_col");
  return dao.deleteCollection(collection);
});
