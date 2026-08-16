/// <reference path="../pb_data/types.d.ts" />

migrate((db) => {
  const collection = new Collection({
    id: "players_col",
    name: "players",
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
        name: "photo",
        type: "file",
        required: false,
        options: {
          maxSelect: 1,
          maxSize: 5242880,
          mimeTypes: ["image/jpeg", "image/png", "image/webp"],
          thumbs: ["100x100", "200x200"],
        },
      },
      {
        name: "position",
        type: "select",
        required: false,
        options: {
          values: [
            "setter",
            "outside_hitter",
            "opposite",
            "middle_blocker",
            "libero",
            "defensive_specialist",
          ],
          maxSelect: 1,
        },
      },
      {
        name: "status",
        type: "select",
        required: true,
        options: {
          values: ["active", "injured", "inactive"],
          maxSelect: 1,
        },
      },
      {
        name: "jersey_number",
        type: "number",
        required: false,
        options: { min: 1, max: 99 },
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
  const collection = dao.findCollectionByNameOrId("players_col");
  return dao.deleteCollection(collection);
});
