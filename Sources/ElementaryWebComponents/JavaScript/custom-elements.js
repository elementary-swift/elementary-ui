export function defineCustomElement(name, implementation) {
  if (import.meta.hot) {
    const existing = customElements.get(name);
    if (existing) {
      existing.swapImplementation(implementation);
      return;
    }
  }

  const elementClass = makeCustomElement();
  elementClass.setImplementation(implementation);
  customElements.define(name, elementClass);
}

function makeCustomElement() {
  return class ElementaryCustomElement extends HTMLElement {
    static {
      if (import.meta.hot) {
        this.__instances = new Set();
        this.swapImplementation = function (implementation) {
          const attributes = implementation.observedAttributes;
          if (
            this.observedAttributes.length !== attributes.length ||
            this.observedAttributes.some((name) => !attributes.includes(name))
          ) {
            location.reload();
            return;
          }

          const instances = [...this.__instances];
          for (const element of instances) {
            this.__elementaryImplementation.disconnect(element);
          }

          this.setImplementation(implementation);

          for (const element of instances) {
            if (element.isConnected) implementation.connect(element);
          }
        };
      }
    }

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
      if (import.meta.hot) this.constructor.__instances.add(this);
      this.constructor.__elementaryImplementation.connect(this);
    }

    disconnectedCallback() {
      if (import.meta.hot) this.constructor.__instances.delete(this);
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
