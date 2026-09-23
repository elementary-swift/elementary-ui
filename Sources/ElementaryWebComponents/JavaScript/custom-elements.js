function construct(element, implementation) {
  implementation.construct(element);
  for (const name of element.constructor.observedAttributes) {
    if (element.hasAttribute(name)) {
      implementation.setAttribute(element, name, element.getAttribute(name));
    }
  }
}

function makeCustomElement(shadowDOM, observedAttributes, implementation) {
  return class ElementaryCustomElement extends HTMLElement {
    static __elementaryImplementation = implementation;
    static __elementaryShadowDOM = shadowDOM;

    static get observedAttributes() {
      return observedAttributes;
    }

    constructor() {
      super();
      implementation.construct(this);
    }

    connectedCallback() {
      const implementation = this.constructor.__elementaryImplementation;
      construct(this, implementation);
      implementation.connect(this);
    }

    disconnectedCallback() {
      this.constructor.__elementaryImplementation.destruct(this);
    }

    connectedMoveCallback() {}

    attributeChangedCallback(name, oldValue, newValue) {
      if (oldValue !== newValue) {
        this.constructor.__elementaryImplementation.setAttribute(
          this,
          name,
          newValue
        );
      }
    }
  };
}

function replaceImplementation(name, elementClass, implementation) {
  const instances = document.querySelectorAll(name);
  for (const element of instances) {
    elementClass.__elementaryImplementation.destruct(element);
  }

  elementClass.__elementaryImplementation = implementation;

  for (const element of instances) {
    construct(element, implementation);
    implementation.connect(element);
  }
}

export function defineCustomElement(
  name,
  shadowDOM,
  observedAttributes,
  implementation
) {
  const existing = customElements.get(name);
  if (existing && import.meta.hot) {
    if (
      existing.__elementaryShadowDOM !== shadowDOM ||
      existing.observedAttributes.join("\0") !== observedAttributes.join("\0")
    ) {
      const message =
        `Elementary custom element metadata changed for <${name}>; full reload required`;
      console.info(message);
      import.meta.hot.invalidate(message);
      return;
    }

    replaceImplementation(name, existing, implementation);
    return;
  }

  customElements.define(
    name,
    makeCustomElement(shadowDOM, observedAttributes, implementation)
  );
}
