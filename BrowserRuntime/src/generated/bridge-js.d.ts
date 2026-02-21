// NOTICE: This is auto-generated code by BridgeJS from JavaScriptKit,
// DO NOT EDIT.
//
// To update this file, just rebuild your project or run
// `swift package bridge-js`.

export interface JSDocument {
    createElement(tagName: string): JSElement;
    createTextNode(text: string): JSNode;
    querySelector(selector: string): JSElement;
    addEventListener(type: string, listener: any): void;
    removeEventListener(type: string, listener: any): void;
    readonly body: JSElement;
}
export interface JSWindow {
    getComputedStyle(element: JSElement): JSCSSStyleDeclaration;
    readonly scrollX: number;
    readonly scrollY: number;
}
export interface JSPerformance {
    now(): number;
}
export interface JSNode {
    textContent: string | null;
}
export interface JSElement {
    setAttribute(name: string, value: string): void;
    removeAttribute(name: string): void;
    appendChild(child: JSNode): void;
    removeChild(child: JSNode): void;
    getBoundingClientRect(): JSDOMRect;
    addEventListener(type: string, listener: any): void;
    removeEventListener(type: string, listener: any): void;
    focus(): void;
    blur(): void;
    animate(keyframes: any, options: any): JSAnimation;
    readonly style: JSCSSStyleDeclaration;
    textContent: string | null;
    readonly offsetParent: JSElement;
}
export interface JSCSSStyleDeclaration {
    getPropertyValue(name: string): string;
    setProperty(name: string, value: string): void;
    removeProperty(name: string): void;
}
export interface JSDOMRect {
    readonly x: number;
    readonly y: number;
    readonly width: number;
    readonly height: number;
}
export interface JSAnimation {
    persist(): void;
    pause(): void;
    play(): void;
    cancel(): void;
    readonly effect: JSAnimationEffect;
    currentTime: number;
    onfinish: any | null;
}
export interface JSAnimationEffect {
    setKeyframes(keyframes: any): void;
    updateTiming(timing: any): void;
}
export interface JSEvent {
    readonly type: string;
    readonly target: any;
}
export interface JSKeyboardEvent {
    readonly key: string;
}
export interface JSMouseEvent {
    readonly altKey: boolean;
    readonly button: number;
    readonly buttons: number;
    readonly clientX: number;
    readonly clientY: number;
    readonly ctrlKey: boolean;
    readonly metaKey: boolean;
    readonly movementX: number;
    readonly movementY: number;
    readonly offsetX: number;
    readonly offsetY: number;
    readonly pageX: number;
    readonly pageY: number;
    readonly screenX: number;
    readonly screenY: number;
    readonly shiftKey: boolean;
}
export interface JSInputEvent {
    readonly data: string | null;
    readonly target: any;
}
export type Exports = {
}
export type Imports = {
}
export function createInstantiator(options: {
    imports: Imports;
}, swift: any): Promise<{
    addImports: (importObject: WebAssembly.Imports) => void;
    setInstance: (instance: WebAssembly.Instance) => void;
    createExports: (instance: WebAssembly.Instance) => Exports;
}>;
