const fs = require("fs");

const raw = fs.readFileSync("moon.mod.json");
const data = JSON.parse(raw);
delete data["deps"];
fs.writeFileSync("moon.mod.json", JSON.stringify(data, null, 2));

fs.rmSync("src/internal_benchmark", { recursive: true });
fs.rmSync("src/testing", { recursive: true });