import { defineCustomElement } from "../../Sources/ElementaryWebComponents/JavaScript/custom-elements.js";

const implementation = {
  connect: () => {},
  setAttribute: () => {},
  destruct: () => {},
};

(globalThis as any).__triggerElementaryMetadataMismatch = () => {
  defineCustomElement("test-metadata-counter", "open", ["value"], implementation);
  defineCustomElement("test-metadata-counter", "none", ["value"], implementation);
};
