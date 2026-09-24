export function defineCustomElement(name, implementation) {
  if (import.meta.hot) {
    const existing = customElements.get(name);
    if (existing) {
      const instances = document.querySelectorAll(name);
      for (const element of instances) {
        existing.__elementaryImplementation.disconnect(element);
      }

      existing.setImplementation(implementation);

      for (const element of instances) {
        implementation.connect(element);
      }
      return;
    }
  }

  const elementClass = makeCustomElement();
  elementClass.setImplementation(implementation);
  customElements.define(name, elementClass);
}

function makeCustomElement() {
  return class ElementaryCustomElement extends HTMLElement {
    static setImplementation(implementation) {
      this.__elementaryImplementation = implementation;
      this.__observedAttributes = implementation.observedAttributes;
    }

    static get observedAttributes() {
      return this.__observedAttributes;
    }

    constructor() {
      super();
    }

    connectedCallback() {
      this.constructor.__elementaryImplementation.connect(this);
    }

    disconnectedCallback() {
      this.constructor.__elementaryImplementation.disconnect(this);
    }

    connectedMoveCallback() {}

    attributeChangedCallback(name, oldValue, newValue) {
      if (oldValue !== newValue) {
        this.constructor.__elementaryImplementation.setAttribute(
          this,
          name,
          newValue,
        );
      }
    }
  };
}
