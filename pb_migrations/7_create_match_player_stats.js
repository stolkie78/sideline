/// <reference path="../pb_data/types.d.ts" />

migrate((db) => {
  const collection = new Collection({
    id: "match_player_stats_col",
    name: "match_player_stats",
    type: "base",
    system: false,
    schema: [
      {
        name: "match",
        type: "relation",
        required: true,
        options: {
          collectionId: "matches_col",
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
        name: "playing_time",
        type: "number",
        required: false,
        options: { min: 0, max: 300 },
      },
      {
        name: "sets_played",
        type: "number",
        required: false,
        options: { min: 0, max: 5 },
      },
      {
        name: "rating",
        type: "number",
        required: false,
        options: { min: 1, max: 10 },
      },
      {
        name: "notes",
        type: "text",
        required: false,
        options: { max: 1000 },
      },
    ],
    indexes: [
      "CREATE INDEX idx_mps_match ON match_player_stats (match)",
      "CREATE INDEX idx_mps_player ON match_player_stats (player)",
      "CREATE UNIQUE INDEX idx_mps_unique ON match_player_stats (match, player)",
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
  const collection = dao.findCollectionByNameOrId("match_player_stats_col");
  return dao.deleteCollection(collection);
});
