// NOTICE: This is auto-generated code by BridgeJS from JavaScriptKit,
// DO NOT EDIT.
//
// To update this file, just rebuild your project or run
// `swift package bridge-js`.

export async function createInstantiator(options, swift) {
    let instance;
    let memory;
    let setException;
    const textDecoder = new TextDecoder("utf-8");
    const textEncoder = new TextEncoder("utf-8");
    let tmpRetString;
    let tmpRetBytes;
    let tmpRetException;
    let tmpRetOptionalBool;
    let tmpRetOptionalInt;
    let tmpRetOptionalFloat;
    let tmpRetOptionalDouble;
    let tmpRetOptionalHeapObject;
    let strStack = [];
    let i32Stack = [];
    let f32Stack = [];
    let f64Stack = [];
    let ptrStack = [];
    const enumHelpers = {};
    const structHelpers = {};

    let _exports = null;
    let bjs = null;
    const swiftClosureRegistry = (typeof FinalizationRegistry === "undefined") ? { register: () => {}, unregister: () => {} } : new FinalizationRegistry((state) => {
        if (state.unregistered) { return; }
        instance?.exports?.bjs_release_swift_closure(state.pointer);
    });
    const makeClosure = (pointer, file, line, func) => {
        const state = { pointer, file, line, unregistered: false };
        const real = (...args) => {
            if (state.unregistered) {
                const bytes = new Uint8Array(memory.buffer, state.file);
                let length = 0;
                while (bytes[length] !== 0) { length += 1; }
                const fileID = textDecoder.decode(bytes.subarray(0, length));
                throw new Error(`Attempted to call a released JSTypedClosure created at ${fileID}:${state.line}`);
            }
            return func(...args);
        };
        real.__unregister = () => {
            if (state.unregistered) { return; }
            state.unregistered = true;
            swiftClosureRegistry.unregister(state);
        };
        swiftClosureRegistry.register(real, state, state);
        return swift.memory.retain(real);
    };


    return {
        /**
         * @param {WebAssembly.Imports} importObject
         */
        addImports: (importObject, importsContext) => {
            bjs = {};
            importObject["bjs"] = bjs;
            bjs["swift_js_return_string"] = function(ptr, len) {
                const bytes = new Uint8Array(memory.buffer, ptr, len);
                tmpRetString = textDecoder.decode(bytes);
            }
            bjs["swift_js_init_memory"] = function(sourceId, bytesPtr) {
                const source = swift.memory.getObject(sourceId);
                swift.memory.release(sourceId);
                const bytes = new Uint8Array(memory.buffer, bytesPtr);
                bytes.set(source);
            }
            bjs["swift_js_make_js_string"] = function(ptr, len) {
                const bytes = new Uint8Array(memory.buffer, ptr, len);
                return swift.memory.retain(textDecoder.decode(bytes));
            }
            bjs["swift_js_init_memory_with_result"] = function(ptr, len) {
                const target = new Uint8Array(memory.buffer, ptr, len);
                target.set(tmpRetBytes);
                tmpRetBytes = undefined;
            }
            bjs["swift_js_throw"] = function(id) {
                tmpRetException = swift.memory.retainByRef(id);
            }
            bjs["swift_js_retain"] = function(id) {
                return swift.memory.retainByRef(id);
            }
            bjs["swift_js_release"] = function(id) {
                swift.memory.release(id);
            }
            bjs["swift_js_push_i32"] = function(v) {
                i32Stack.push(v | 0);
            }
            bjs["swift_js_push_f32"] = function(v) {
                f32Stack.push(Math.fround(v));
            }
            bjs["swift_js_push_f64"] = function(v) {
                f64Stack.push(v);
            }
            bjs["swift_js_push_string"] = function(ptr, len) {
                const bytes = new Uint8Array(memory.buffer, ptr, len);
                const value = textDecoder.decode(bytes);
                strStack.push(value);
            }
            bjs["swift_js_pop_i32"] = function() {
                return i32Stack.pop();
            }
            bjs["swift_js_pop_f32"] = function() {
                return f32Stack.pop();
            }
            bjs["swift_js_pop_f64"] = function() {
                return f64Stack.pop();
            }
            bjs["swift_js_push_pointer"] = function(pointer) {
                ptrStack.push(pointer);
            }
            bjs["swift_js_pop_pointer"] = function() {
                return ptrStack.pop();
            }
            bjs["swift_js_return_optional_bool"] = function(isSome, value) {
                if (isSome === 0) {
                    tmpRetOptionalBool = null;
                } else {
                    tmpRetOptionalBool = value !== 0;
                }
            }
            bjs["swift_js_return_optional_int"] = function(isSome, value) {
                if (isSome === 0) {
                    tmpRetOptionalInt = null;
                } else {
                    tmpRetOptionalInt = value | 0;
                }
            }
            bjs["swift_js_return_optional_float"] = function(isSome, value) {
                if (isSome === 0) {
                    tmpRetOptionalFloat = null;
                } else {
                    tmpRetOptionalFloat = Math.fround(value);
                }
            }
            bjs["swift_js_return_optional_double"] = function(isSome, value) {
                if (isSome === 0) {
                    tmpRetOptionalDouble = null;
                } else {
                    tmpRetOptionalDouble = value;
                }
            }
            bjs["swift_js_return_optional_string"] = function(isSome, ptr, len) {
                if (isSome === 0) {
                    tmpRetString = null;
                } else {
                    const bytes = new Uint8Array(memory.buffer, ptr, len);
                    tmpRetString = textDecoder.decode(bytes);
                }
            }
            bjs["swift_js_return_optional_object"] = function(isSome, objectId) {
                if (isSome === 0) {
                    tmpRetString = null;
                } else {
                    tmpRetString = swift.memory.getObject(objectId);
                }
            }
            bjs["swift_js_return_optional_heap_object"] = function(isSome, pointer) {
                if (isSome === 0) {
                    tmpRetOptionalHeapObject = null;
                } else {
                    tmpRetOptionalHeapObject = pointer;
                }
            }
            bjs["swift_js_get_optional_int_presence"] = function() {
                return tmpRetOptionalInt != null ? 1 : 0;
            }
            bjs["swift_js_get_optional_int_value"] = function() {
                const value = tmpRetOptionalInt;
                tmpRetOptionalInt = undefined;
                return value;
            }
            bjs["swift_js_get_optional_string"] = function() {
                const str = tmpRetString;
                tmpRetString = undefined;
                if (str == null) {
                    return -1;
                } else {
                    const bytes = textEncoder.encode(str);
                    tmpRetBytes = bytes;
                    return bytes.length;
                }
            }
            bjs["swift_js_get_optional_float_presence"] = function() {
                return tmpRetOptionalFloat != null ? 1 : 0;
            }
            bjs["swift_js_get_optional_float_value"] = function() {
                const value = tmpRetOptionalFloat;
                tmpRetOptionalFloat = undefined;
                return value;
            }
            bjs["swift_js_get_optional_double_presence"] = function() {
                return tmpRetOptionalDouble != null ? 1 : 0;
            }
            bjs["swift_js_get_optional_double_value"] = function() {
                const value = tmpRetOptionalDouble;
                tmpRetOptionalDouble = undefined;
                return value;
            }
            bjs["swift_js_get_optional_heap_object_pointer"] = function() {
                const pointer = tmpRetOptionalHeapObject;
                tmpRetOptionalHeapObject = undefined;
                return pointer || 0;
            }
            bjs["swift_js_closure_unregister"] = function(funcRef) {}
            bjs["swift_js_closure_unregister"] = function(funcRef) {
                const func = swift.memory.getObject(funcRef);
                func.__unregister();
            }
            bjs["invoke_js_callback_BrowserInterop_14BrowserInteropSd_y"] = function(callbackId, param0) {
                try {
                    const callback = swift.memory.getObject(callbackId);
                    callback(param0);
                } catch (error) {
                    setException(error);
                }
            }
            bjs["make_swift_closure_BrowserInterop_14BrowserInteropSd_y"] = function(boxPtr, file, line) {
                const lower_closure_BrowserInterop_14BrowserInteropSd_y = function(param0) {
                    instance.exports.invoke_swift_closure_BrowserInterop_14BrowserInteropSd_y(boxPtr, param0);
                    if (tmpRetException) {
                        const error = swift.memory.getObject(tmpRetException);
                        swift.memory.release(tmpRetException);
                        tmpRetException = undefined;
                        throw error;
                    }
                };
                return makeClosure(boxPtr, file, line, lower_closure_BrowserInterop_14BrowserInteropSd_y);
            }
            bjs["invoke_js_callback_BrowserInterop_14BrowserInteropy_y"] = function(callbackId) {
                try {
                    const callback = swift.memory.getObject(callbackId);
                    callback();
                } catch (error) {
                    setException(error);
                }
            }
            bjs["make_swift_closure_BrowserInterop_14BrowserInteropy_y"] = function(boxPtr, file, line) {
                const lower_closure_BrowserInterop_14BrowserInteropy_y = function() {
                    instance.exports.invoke_swift_closure_BrowserInterop_14BrowserInteropy_y(boxPtr);
                    if (tmpRetException) {
                        const error = swift.memory.getObject(tmpRetException);
                        swift.memory.release(tmpRetException);
                        tmpRetException = undefined;
                        throw error;
                    }
                };
                return makeClosure(boxPtr, file, line, lower_closure_BrowserInterop_14BrowserInteropy_y);
            }
            const BrowserInterop = importObject["BrowserInterop"] = importObject["BrowserInterop"] || {};
            BrowserInterop["bjs_JSDocument_body_get"] = function bjs_JSDocument_body_get(self) {
                try {
                    let ret = swift.memory.getObject(self).body;
                    return swift.memory.retain(ret);
                } catch (error) {
                    setException(error);
                    return 0
                }
            }
            BrowserInterop["bjs_JSDocument_createElement"] = function bjs_JSDocument_createElement(self, tagName) {
                try {
                    const tagNameObject = swift.memory.getObject(tagName);
                    swift.memory.release(tagName);
                    let ret = swift.memory.getObject(self).createElement(tagNameObject);
                    return swift.memory.retain(ret);
                } catch (error) {
                    setException(error);
                    return 0
                }
            }
            BrowserInterop["bjs_JSDocument_createTextNode"] = function bjs_JSDocument_createTextNode(self, text) {
                try {
                    const textObject = swift.memory.getObject(text);
                    swift.memory.release(text);
                    let ret = swift.memory.getObject(self).createTextNode(textObject);
                    return swift.memory.retain(ret);
                } catch (error) {
                    setException(error);
                    return 0
                }
            }
            BrowserInterop["bjs_JSDocument_querySelector"] = function bjs_JSDocument_querySelector(self, selector) {
                try {
                    const selectorObject = swift.memory.getObject(selector);
                    swift.memory.release(selector);
                    let ret = swift.memory.getObject(self).querySelector(selectorObject);
                    return swift.memory.retain(ret);
                } catch (error) {
                    setException(error);
                    return 0
                }
            }
            BrowserInterop["bjs_JSDocument_addEventListener"] = function bjs_JSDocument_addEventListener(self, type, listener) {
                try {
                    const typeObject = swift.memory.getObject(type);
                    swift.memory.release(type);
                    swift.memory.getObject(self).addEventListener(typeObject, swift.memory.getObject(listener));
                } catch (error) {
                    setException(error);
                }
            }
            BrowserInterop["bjs_JSDocument_removeEventListener"] = function bjs_JSDocument_removeEventListener(self, type, listener) {
                try {
                    const typeObject = swift.memory.getObject(type);
                    swift.memory.release(type);
                    swift.memory.getObject(self).removeEventListener(typeObject, swift.memory.getObject(listener));
                } catch (error) {
                    setException(error);
                }
            }
            BrowserInterop["bjs_JSWindow_scrollX_get"] = function bjs_JSWindow_scrollX_get(self) {
                try {
                    let ret = swift.memory.getObject(self).scrollX;
                    return ret;
                } catch (error) {
                    setException(error);
                    return 0
                }
            }
            BrowserInterop["bjs_JSWindow_scrollY_get"] = function bjs_JSWindow_scrollY_get(self) {
                try {
                    let ret = swift.memory.getObject(self).scrollY;
                    return ret;
                } catch (error) {
                    setException(error);
                    return 0
                }
            }
            BrowserInterop["bjs_JSWindow_getComputedStyle"] = function bjs_JSWindow_getComputedStyle(self, element) {
                try {
                    let ret = swift.memory.getObject(self).getComputedStyle(swift.memory.getObject(element));
                    return swift.memory.retain(ret);
                } catch (error) {
                    setException(error);
                    return 0
                }
            }
            BrowserInterop["bjs_JSPerformance_now"] = function bjs_JSPerformance_now(self) {
                try {
                    let ret = swift.memory.getObject(self).now();
                    return ret;
                } catch (error) {
                    setException(error);
                    return 0
                }
            }
            BrowserInterop["bjs_JSNode_textContent_get"] = function bjs_JSNode_textContent_get(self) {
                try {
                    let ret = swift.memory.getObject(self).textContent;
                    const isSome = ret != null;
                    tmpRetString = isSome ? ret : null;
                } catch (error) {
                    setException(error);
                }
            }
            BrowserInterop["bjs_JSNode_textContent_set"] = function bjs_JSNode_textContent_set(self, newValueIsSome, newValueObjectId) {
                try {
                    let optResult;
                    if (newValueIsSome) {
                        const newValueObjectIdObject = swift.memory.getObject(newValueObjectId);
                        swift.memory.release(newValueObjectId);
                        optResult = newValueObjectIdObject;
                    } else {
                        optResult = null;
                    }
                    swift.memory.getObject(self).textContent = optResult;
                } catch (error) {
                    setException(error);
                }
            }
            BrowserInterop["bjs_JSElement_style_get"] = function bjs_JSElement_style_get(self) {
                try {
                    let ret = swift.memory.getObject(self).style;
                    return swift.memory.retain(ret);
                } catch (error) {
                    setException(error);
                    return 0
                }
            }
            BrowserInterop["bjs_JSElement_textContent_get"] = function bjs_JSElement_textContent_get(self) {
                try {
                    let ret = swift.memory.getObject(self).textContent;
                    const isSome = ret != null;
                    tmpRetString = isSome ? ret : null;
                } catch (error) {
                    setException(error);
                }
            }
            BrowserInterop["bjs_JSElement_offsetParent_get"] = function bjs_JSElement_offsetParent_get(self) {
                try {
                    let ret = swift.memory.getObject(self).offsetParent;
                    return swift.memory.retain(ret);
                } catch (error) {
                    setException(error);
                    return 0
                }
            }
            BrowserInterop["bjs_JSElement_textContent_set"] = function bjs_JSElement_textContent_set(self, newValueIsSome, newValueObjectId) {
                try {
                    let optResult;
                    if (newValueIsSome) {
                        const newValueObjectIdObject = swift.memory.getObject(newValueObjectId);
                        swift.memory.release(newValueObjectId);
                        optResult = newValueObjectIdObject;
                    } else {
                        optResult = null;
                    }
                    swift.memory.getObject(self).textContent = optResult;
                } catch (error) {
                    setException(error);
                }
            }
            BrowserInterop["bjs_JSElement_setAttribute"] = function bjs_JSElement_setAttribute(self, name, value) {
                try {
                    const nameObject = swift.memory.getObject(name);
                    swift.memory.release(name);
                    const valueObject = swift.memory.getObject(value);
                    swift.memory.release(value);
                    swift.memory.getObject(self).setAttribute(nameObject, valueObject);
                } catch (error) {
                    setException(error);
                }
            }
            BrowserInterop["bjs_JSElement_removeAttribute"] = function bjs_JSElement_removeAttribute(self, name) {
                try {
                    const nameObject = swift.memory.getObject(name);
                    swift.memory.release(name);
                    swift.memory.getObject(self).removeAttribute(nameObject);
                } catch (error) {
                    setException(error);
                }
            }
            BrowserInterop["bjs_JSElement_appendChild"] = function bjs_JSElement_appendChild(self, child) {
                try {
                    swift.memory.getObject(self).appendChild(swift.memory.getObject(child));
                } catch (error) {
                    setException(error);
                }
            }
            BrowserInterop["bjs_JSElement_removeChild"] = function bjs_JSElement_removeChild(self, child) {
                try {
                    swift.memory.getObject(self).removeChild(swift.memory.getObject(child));
                } catch (error) {
                    setException(error);
                }
            }
            BrowserInterop["bjs_JSElement_getBoundingClientRect"] = function bjs_JSElement_getBoundingClientRect(self) {
                try {
                    let ret = swift.memory.getObject(self).getBoundingClientRect();
                    return swift.memory.retain(ret);
                } catch (error) {
                    setException(error);
                    return 0
                }
            }
            BrowserInterop["bjs_JSElement_addEventListener"] = function bjs_JSElement_addEventListener(self, type, listener) {
                try {
                    const typeObject = swift.memory.getObject(type);
                    swift.memory.release(type);
                    swift.memory.getObject(self).addEventListener(typeObject, swift.memory.getObject(listener));
                } catch (error) {
                    setException(error);
                }
            }
            BrowserInterop["bjs_JSElement_removeEventListener"] = function bjs_JSElement_removeEventListener(self, type, listener) {
                try {
                    const typeObject = swift.memory.getObject(type);
                    swift.memory.release(type);
                    swift.memory.getObject(self).removeEventListener(typeObject, swift.memory.getObject(listener));
                } catch (error) {
                    setException(error);
                }
            }
            BrowserInterop["bjs_JSElement_focus"] = function bjs_JSElement_focus(self) {
                try {
                    swift.memory.getObject(self).focus();
                } catch (error) {
                    setException(error);
                }
            }
            BrowserInterop["bjs_JSElement_blur"] = function bjs_JSElement_blur(self) {
                try {
                    swift.memory.getObject(self).blur();
                } catch (error) {
                    setException(error);
                }
            }
            BrowserInterop["bjs_JSElement_animate"] = function bjs_JSElement_animate(self, keyframes, options) {
                try {
                    let ret = swift.memory.getObject(self).animate(swift.memory.getObject(keyframes), swift.memory.getObject(options));
                    return swift.memory.retain(ret);
                } catch (error) {
                    setException(error);
                    return 0
                }
            }
            BrowserInterop["bjs_JSCSSStyleDeclaration_getPropertyValue"] = function bjs_JSCSSStyleDeclaration_getPropertyValue(self, name) {
                try {
                    const nameObject = swift.memory.getObject(name);
                    swift.memory.release(name);
                    let ret = swift.memory.getObject(self).getPropertyValue(nameObject);
                    tmpRetBytes = textEncoder.encode(ret);
                    return tmpRetBytes.length;
                } catch (error) {
                    setException(error);
                }
            }
            BrowserInterop["bjs_JSCSSStyleDeclaration_setProperty"] = function bjs_JSCSSStyleDeclaration_setProperty(self, name, value) {
                try {
                    const nameObject = swift.memory.getObject(name);
                    swift.memory.release(name);
                    const valueObject = swift.memory.getObject(value);
                    swift.memory.release(value);
                    swift.memory.getObject(self).setProperty(nameObject, valueObject);
                } catch (error) {
                    setException(error);
                }
            }
            BrowserInterop["bjs_JSCSSStyleDeclaration_removeProperty"] = function bjs_JSCSSStyleDeclaration_removeProperty(self, name) {
                try {
                    const nameObject = swift.memory.getObject(name);
                    swift.memory.release(name);
                    swift.memory.getObject(self).removeProperty(nameObject);
                } catch (error) {
                    setException(error);
                }
            }
            BrowserInterop["bjs_JSDOMRect_x_get"] = function bjs_JSDOMRect_x_get(self) {
                try {
                    let ret = swift.memory.getObject(self).x;
                    return ret;
                } catch (error) {
                    setException(error);
                    return 0
                }
            }
            BrowserInterop["bjs_JSDOMRect_y_get"] = function bjs_JSDOMRect_y_get(self) {
                try {
                    let ret = swift.memory.getObject(self).y;
                    return ret;
                } catch (error) {
                    setException(error);
                    return 0
                }
            }
            BrowserInterop["bjs_JSDOMRect_width_get"] = function bjs_JSDOMRect_width_get(self) {
                try {
                    let ret = swift.memory.getObject(self).width;
                    return ret;
                } catch (error) {
                    setException(error);
                    return 0
                }
            }
            BrowserInterop["bjs_JSDOMRect_height_get"] = function bjs_JSDOMRect_height_get(self) {
                try {
                    let ret = swift.memory.getObject(self).height;
                    return ret;
                } catch (error) {
                    setException(error);
                    return 0
                }
            }
            BrowserInterop["bjs_JSAnimation_effect_get"] = function bjs_JSAnimation_effect_get(self) {
                try {
                    let ret = swift.memory.getObject(self).effect;
                    return swift.memory.retain(ret);
                } catch (error) {
                    setException(error);
                    return 0
                }
            }
            BrowserInterop["bjs_JSAnimation_currentTime_set"] = function bjs_JSAnimation_currentTime_set(self, newValue) {
                try {
                    swift.memory.getObject(self).currentTime = newValue;
                } catch (error) {
                    setException(error);
                }
            }
            BrowserInterop["bjs_JSAnimation_onfinish_set"] = function bjs_JSAnimation_onfinish_set(self, newValueIsSome, newValueObjectId) {
                try {
                    swift.memory.getObject(self).onfinish = newValueIsSome ? swift.memory.getObject(newValueObjectId) : null;
                } catch (error) {
                    setException(error);
                }
            }
            BrowserInterop["bjs_JSAnimation_persist"] = function bjs_JSAnimation_persist(self) {
                try {
                    swift.memory.getObject(self).persist();
                } catch (error) {
                    setException(error);
                }
            }
            BrowserInterop["bjs_JSAnimation_pause"] = function bjs_JSAnimation_pause(self) {
                try {
                    swift.memory.getObject(self).pause();
                } catch (error) {
                    setException(error);
                }
            }
            BrowserInterop["bjs_JSAnimation_play"] = function bjs_JSAnimation_play(self) {
                try {
                    swift.memory.getObject(self).play();
                } catch (error) {
                    setException(error);
                }
            }
            BrowserInterop["bjs_JSAnimation_cancel"] = function bjs_JSAnimation_cancel(self) {
                try {
                    swift.memory.getObject(self).cancel();
                } catch (error) {
                    setException(error);
                }
            }
            BrowserInterop["bjs_JSAnimationEffect_setKeyframes"] = function bjs_JSAnimationEffect_setKeyframes(self, keyframes) {
                try {
                    swift.memory.getObject(self).setKeyframes(swift.memory.getObject(keyframes));
                } catch (error) {
                    setException(error);
                }
            }
            BrowserInterop["bjs_JSAnimationEffect_updateTiming"] = function bjs_JSAnimationEffect_updateTiming(self, timing) {
                try {
                    swift.memory.getObject(self).updateTiming(swift.memory.getObject(timing));
                } catch (error) {
                    setException(error);
                }
            }
            BrowserInterop["bjs_JSEvent_type_get"] = function bjs_JSEvent_type_get(self) {
                try {
                    let ret = swift.memory.getObject(self).type;
                    tmpRetBytes = textEncoder.encode(ret);
                    return tmpRetBytes.length;
                } catch (error) {
                    setException(error);
                }
            }
            BrowserInterop["bjs_JSEvent_target_get"] = function bjs_JSEvent_target_get(self) {
                try {
                    let ret = swift.memory.getObject(self).target;
                    return swift.memory.retain(ret);
                } catch (error) {
                    setException(error);
                    return 0
                }
            }
            BrowserInterop["bjs_JSKeyboardEvent_key_get"] = function bjs_JSKeyboardEvent_key_get(self) {
                try {
                    let ret = swift.memory.getObject(self).key;
                    tmpRetBytes = textEncoder.encode(ret);
                    return tmpRetBytes.length;
                } catch (error) {
                    setException(error);
                }
            }
            BrowserInterop["bjs_JSMouseEvent_altKey_get"] = function bjs_JSMouseEvent_altKey_get(self) {
                try {
                    let ret = swift.memory.getObject(self).altKey;
                    return ret ? 1 : 0;
                } catch (error) {
                    setException(error);
                    return 0
                }
            }
            BrowserInterop["bjs_JSMouseEvent_button_get"] = function bjs_JSMouseEvent_button_get(self) {
                try {
                    let ret = swift.memory.getObject(self).button;
                    return ret;
                } catch (error) {
                    setException(error);
                    return 0
                }
            }
            BrowserInterop["bjs_JSMouseEvent_buttons_get"] = function bjs_JSMouseEvent_buttons_get(self) {
                try {
                    let ret = swift.memory.getObject(self).buttons;
                    return ret;
                } catch (error) {
                    setException(error);
                    return 0
                }
            }
            BrowserInterop["bjs_JSMouseEvent_clientX_get"] = function bjs_JSMouseEvent_clientX_get(self) {
                try {
                    let ret = swift.memory.getObject(self).clientX;
                    return ret;
                } catch (error) {
                    setException(error);
                    return 0
                }
            }
            BrowserInterop["bjs_JSMouseEvent_clientY_get"] = function bjs_JSMouseEvent_clientY_get(self) {
                try {
                    let ret = swift.memory.getObject(self).clientY;
                    return ret;
                } catch (error) {
                    setException(error);
                    return 0
                }
            }
            BrowserInterop["bjs_JSMouseEvent_ctrlKey_get"] = function bjs_JSMouseEvent_ctrlKey_get(self) {
                try {
                    let ret = swift.memory.getObject(self).ctrlKey;
                    return ret ? 1 : 0;
                } catch (error) {
                    setException(error);
                    return 0
                }
            }
            BrowserInterop["bjs_JSMouseEvent_metaKey_get"] = function bjs_JSMouseEvent_metaKey_get(self) {
                try {
                    let ret = swift.memory.getObject(self).metaKey;
                    return ret ? 1 : 0;
                } catch (error) {
                    setException(error);
                    return 0
                }
            }
            BrowserInterop["bjs_JSMouseEvent_movementX_get"] = function bjs_JSMouseEvent_movementX_get(self) {
                try {
                    let ret = swift.memory.getObject(self).movementX;
                    return ret;
                } catch (error) {
                    setException(error);
                    return 0
                }
            }
            BrowserInterop["bjs_JSMouseEvent_movementY_get"] = function bjs_JSMouseEvent_movementY_get(self) {
                try {
                    let ret = swift.memory.getObject(self).movementY;
                    return ret;
                } catch (error) {
                    setException(error);
                    return 0
                }
            }
            BrowserInterop["bjs_JSMouseEvent_offsetX_get"] = function bjs_JSMouseEvent_offsetX_get(self) {
                try {
                    let ret = swift.memory.getObject(self).offsetX;
                    return ret;
                } catch (error) {
                    setException(error);
                    return 0
                }
            }
            BrowserInterop["bjs_JSMouseEvent_offsetY_get"] = function bjs_JSMouseEvent_offsetY_get(self) {
                try {
                    let ret = swift.memory.getObject(self).offsetY;
                    return ret;
                } catch (error) {
                    setException(error);
                    return 0
                }
            }
            BrowserInterop["bjs_JSMouseEvent_pageX_get"] = function bjs_JSMouseEvent_pageX_get(self) {
                try {
                    let ret = swift.memory.getObject(self).pageX;
                    return ret;
                } catch (error) {
                    setException(error);
                    return 0
                }
            }
            BrowserInterop["bjs_JSMouseEvent_pageY_get"] = function bjs_JSMouseEvent_pageY_get(self) {
                try {
                    let ret = swift.memory.getObject(self).pageY;
                    return ret;
                } catch (error) {
                    setException(error);
                    return 0
                }
            }
            BrowserInterop["bjs_JSMouseEvent_screenX_get"] = function bjs_JSMouseEvent_screenX_get(self) {
                try {
                    let ret = swift.memory.getObject(self).screenX;
                    return ret;
                } catch (error) {
                    setException(error);
                    return 0
                }
            }
            BrowserInterop["bjs_JSMouseEvent_screenY_get"] = function bjs_JSMouseEvent_screenY_get(self) {
                try {
                    let ret = swift.memory.getObject(self).screenY;
                    return ret;
                } catch (error) {
                    setException(error);
                    return 0
                }
            }
            BrowserInterop["bjs_JSMouseEvent_shiftKey_get"] = function bjs_JSMouseEvent_shiftKey_get(self) {
                try {
                    let ret = swift.memory.getObject(self).shiftKey;
                    return ret ? 1 : 0;
                } catch (error) {
                    setException(error);
                    return 0
                }
            }
            BrowserInterop["bjs_JSInputEvent_data_get"] = function bjs_JSInputEvent_data_get(self) {
                try {
                    let ret = swift.memory.getObject(self).data;
                    const isSome = ret != null;
                    tmpRetString = isSome ? ret : null;
                } catch (error) {
                    setException(error);
                }
            }
            BrowserInterop["bjs_JSInputEvent_target_get"] = function bjs_JSInputEvent_target_get(self) {
                try {
                    let ret = swift.memory.getObject(self).target;
                    return swift.memory.retain(ret);
                } catch (error) {
                    setException(error);
                    return 0
                }
            }
            BrowserInterop["bjs_window_get"] = function bjs_window_get() {
                try {
                    let ret = globalThis.window;
                    return swift.memory.retain(ret);
                } catch (error) {
                    setException(error);
                    return 0
                }
            }
            BrowserInterop["bjs_document_get"] = function bjs_document_get() {
                try {
                    let ret = globalThis.document;
                    return swift.memory.retain(ret);
                } catch (error) {
                    setException(error);
                    return 0
                }
            }
            BrowserInterop["bjs_performance_get"] = function bjs_performance_get() {
                try {
                    let ret = globalThis.performance;
                    return swift.memory.retain(ret);
                } catch (error) {
                    setException(error);
                    return 0
                }
            }
            BrowserInterop["bjs_requestAnimationFrame"] = function bjs_requestAnimationFrame(callback) {
                try {
                    let ret = globalThis.requestAnimationFrame(swift.memory.getObject(callback));
                    return ret;
                } catch (error) {
                    setException(error);
                    return 0
                }
            }
            BrowserInterop["bjs_cancelAnimationFrame"] = function bjs_cancelAnimationFrame(handle) {
                try {
                    globalThis.cancelAnimationFrame(handle);
                } catch (error) {
                    setException(error);
                }
            }
            BrowserInterop["bjs_queueMicrotask"] = function bjs_queueMicrotask(callback) {
                try {
                    globalThis.queueMicrotask(swift.memory.getObject(callback));
                } catch (error) {
                    setException(error);
                }
            }
            BrowserInterop["bjs_setTimeout"] = function bjs_setTimeout(callback, timeout) {
                try {
                    globalThis.setTimeout(swift.memory.getObject(callback), timeout);
                } catch (error) {
                    setException(error);
                }
            }
        },
        setInstance: (i) => {
            instance = i;
            memory = instance.exports.memory;

            setException = (error) => {
                instance.exports._swift_js_exception.value = swift.memory.retain(error)
            }
        },
        /** @param {WebAssembly.Instance} instance */
        createExports: (instance) => {
            const js = swift.memory.heap;
            const exports = {
            };
            _exports = exports;
            return exports;
        },
    }
}
