import { join } from "node:path";

import { mergeTypeDefs } from "@graphql-tools/merge";
import { print } from "graphql";
import { readdir } from "node:fs/promises";

const typeDefsDir = join("..", "graphql-definitions");

const files = await readdir(typeDefsDir);

const typeDefs = await Promise.all(
  files
    .filter((x) => !!x && x.endsWith(".graphql"))
    .map((file) => Bun.file(join(typeDefsDir, file)).text())
);

const mergedSchema = mergeTypeDefs(typeDefs);

await Bun.write(join("..", "bun.generated.graphql"), print(mergedSchema));
