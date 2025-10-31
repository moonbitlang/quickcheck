const fs = require("fs");

fs.rmSync("src/internal_benchmark", { recursive: true });
fs.rmSync("src/testing", { recursive: true });
fs.rmSync("rm_deps.js");