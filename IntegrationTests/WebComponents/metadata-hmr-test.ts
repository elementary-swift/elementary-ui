import { defineCustomElement } from "../../Sources/ElementaryWebComponents/JavaScript/custom-elements.js";

const implementation = {
  construct: () => 1,
  connect: () => {},
  setAttribute: () => {},
  destroy: () => {},
};

(globalThis as any).__triggerElementaryMetadataMismatch = () => {
  defineCustomElement("test-metadata-counter", "open", ["value"], implementation);
  defineCustomElement("test-metadata-counter", "none", ["value"], implementation);
};
