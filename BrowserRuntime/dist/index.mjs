import { ConsoleStdout, File, OpenFile, WASI } from "@bjorn3/browser_wasi_shim";

//#region src/wasi-shim.ts
function createDefaultWASI() {
	return new WASI([], [], [
		new OpenFile(new File([])),
		ConsoleStdout.lineBuffered(console.log),
		ConsoleStdout.lineBuffered(console.error)
	], { debug: false });
}

//#endregion
//#region src/vendored/javascriptkit/index.mjs
var SwiftClosureDeallocator = class {
	constructor(exports$1) {
		if (typeof FinalizationRegistry === "undefined") throw new Error("The Swift part of JavaScriptKit was configured to require the availability of JavaScript WeakRefs. Please build with `-Xswiftc -DJAVASCRIPTKIT_WITHOUT_WEAKREFS` to disable features that use WeakRefs.");
		this.functionRegistry = new FinalizationRegistry((id) => {
			exports$1.swjs_free_host_function(id);
		});
	}
	track(func, func_ref) {
		this.functionRegistry.register(func, func_ref);
	}
};
function assertNever(x, message) {
	throw new Error(message);
}
const MAIN_THREAD_TID = -1;
const decode = (kind, payload1, payload2, objectSpace) => {
	switch (kind) {
		case 0: switch (payload1) {
			case 0: return false;
			case 1: return true;
		}
		case 2: return payload2;
		case 1:
		case 3:
		case 7:
		case 8: return objectSpace.getObject(payload1);
		case 4: return null;
		case 5: return;
		default: assertNever(kind, `JSValue Type kind "${kind}" is not supported`);
	}
};
const decodeArray = (ptr, length, memory, objectSpace) => {
	if (length === 0) return [];
	let result = [];
	for (let index = 0; index < length; index++) {
		const base = ptr + 16 * index;
		const kind = memory.getUint32(base, true);
		const payload1 = memory.getUint32(base + 4, true);
		const payload2 = memory.getFloat64(base + 8, true);
		result.push(decode(kind, payload1, payload2, objectSpace));
	}
	return result;
};
const write = (value, kind_ptr, payload1_ptr, payload2_ptr, is_exception, memory, objectSpace) => {
	const kind = writeAndReturnKindBits(value, payload1_ptr, payload2_ptr, is_exception, memory, objectSpace);
	memory.setUint32(kind_ptr, kind, true);
};
const writeAndReturnKindBits = (value, payload1_ptr, payload2_ptr, is_exception, memory, objectSpace) => {
	const exceptionBit = (is_exception ? 1 : 0) << 31;
	if (value === null) return exceptionBit | 4;
	const writeRef = (kind) => {
		memory.setUint32(payload1_ptr, objectSpace.retain(value), true);
		return exceptionBit | kind;
	};
	const type = typeof value;
	switch (type) {
		case "boolean":
			memory.setUint32(payload1_ptr, value ? 1 : 0, true);
			return exceptionBit | 0;
		case "number":
			memory.setFloat64(payload2_ptr, value, true);
			return exceptionBit | 2;
		case "string": return writeRef(1);
		case "undefined": return exceptionBit | 5;
		case "object": return writeRef(3);
		case "function": return writeRef(3);
		case "symbol": return writeRef(7);
		case "bigint": return writeRef(8);
		default: assertNever(type, `Type "${type}" is not supported yet`);
	}
	throw new Error("Unreachable");
};
function decodeObjectRefs(ptr, length, memory) {
	const result = new Array(length);
	for (let i = 0; i < length; i++) result[i] = memory.getUint32(ptr + 4 * i, true);
	return result;
}
var ITCInterface = class {
	constructor(memory) {
		this.memory = memory;
	}
	send(sendingObject, transferringObjects, sendingContext) {
		return {
			object: this.memory.getObject(sendingObject),
			sendingContext,
			transfer: transferringObjects.map((ref) => this.memory.getObject(ref))
		};
	}
	sendObjects(sendingObjects, transferringObjects, sendingContext) {
		return {
			object: sendingObjects.map((ref) => this.memory.getObject(ref)),
			sendingContext,
			transfer: transferringObjects.map((ref) => this.memory.getObject(ref))
		};
	}
	release(objectRef) {
		this.memory.release(objectRef);
		return {
			object: void 0,
			transfer: []
		};
	}
};
var MessageBroker = class {
	constructor(selfTid, threadChannel, handlers) {
		this.selfTid = selfTid;
		this.threadChannel = threadChannel;
		this.handlers = handlers;
	}
	request(message) {
		if (message.data.targetTid == this.selfTid) this.handlers.onRequest(message);
		else if ("postMessageToWorkerThread" in this.threadChannel) this.threadChannel.postMessageToWorkerThread(message.data.targetTid, message, []);
		else if ("postMessageToMainThread" in this.threadChannel) this.threadChannel.postMessageToMainThread(message, []);
		else throw new Error("unreachable");
	}
	reply(message) {
		if (message.data.sourceTid == this.selfTid) {
			this.handlers.onResponse(message);
			return;
		}
		const transfer = message.data.response.ok ? message.data.response.value.transfer : [];
		if ("postMessageToWorkerThread" in this.threadChannel) this.threadChannel.postMessageToWorkerThread(message.data.sourceTid, message, transfer);
		else if ("postMessageToMainThread" in this.threadChannel) this.threadChannel.postMessageToMainThread(message, transfer);
		else throw new Error("unreachable");
	}
	onReceivingRequest(message) {
		if (message.data.targetTid == this.selfTid) this.handlers.onRequest(message);
		else if ("postMessageToWorkerThread" in this.threadChannel) this.threadChannel.postMessageToWorkerThread(message.data.targetTid, message, []);
		else if ("postMessageToMainThread" in this.threadChannel) throw new Error("unreachable");
	}
	onReceivingResponse(message) {
		if (message.data.sourceTid == this.selfTid) this.handlers.onResponse(message);
		else if ("postMessageToWorkerThread" in this.threadChannel) {
			const transfer = message.data.response.ok ? message.data.response.value.transfer : [];
			this.threadChannel.postMessageToWorkerThread(message.data.sourceTid, message, transfer);
		} else if ("postMessageToMainThread" in this.threadChannel) throw new Error("unreachable");
	}
};
function serializeError(error) {
	if (error instanceof Error) return {
		isError: true,
		value: {
			message: error.message,
			name: error.name,
			stack: error.stack
		}
	};
	return {
		isError: false,
		value: error
	};
}
function deserializeError(error) {
	if (error.isError) return Object.assign(new Error(error.value.message), error.value);
	return error.value;
}
let globalVariable;
if (typeof globalThis !== "undefined") globalVariable = globalThis;
else if (typeof window !== "undefined") globalVariable = window;
else if (typeof global !== "undefined") globalVariable = global;
else if (typeof self !== "undefined") globalVariable = self;
var JSObjectSpace = class {
	constructor() {
		this._heapValueById = /* @__PURE__ */ new Map();
		this._heapValueById.set(1, globalVariable);
		this._heapEntryByValue = /* @__PURE__ */ new Map();
		this._heapEntryByValue.set(globalVariable, {
			id: 1,
			rc: 1
		});
		this._heapNextKey = 2;
	}
	retain(value) {
		const entry = this._heapEntryByValue.get(value);
		if (entry) {
			entry.rc++;
			return entry.id;
		}
		const id = this._heapNextKey++;
		this._heapValueById.set(id, value);
		this._heapEntryByValue.set(value, {
			id,
			rc: 1
		});
		return id;
	}
	retainByRef(ref) {
		return this.retain(this.getObject(ref));
	}
	release(ref) {
		const value = this._heapValueById.get(ref);
		const entry = this._heapEntryByValue.get(value);
		entry.rc--;
		if (entry.rc != 0) return;
		this._heapEntryByValue.delete(value);
		this._heapValueById.delete(ref);
	}
	getObject(ref) {
		const value = this._heapValueById.get(ref);
		if (value === void 0) throw new ReferenceError("Attempted to read invalid reference " + ref);
		return value;
	}
};
var SwiftRuntime = class {
	constructor(options) {
		this.version = 708;
		this.textDecoder = new TextDecoder("utf-8");
		this.textEncoder = new TextEncoder();
		this.UnsafeEventLoopYield = UnsafeEventLoopYield;
		/** @deprecated Use `wasmImports` instead */
		this.importObjects = () => this.wasmImports;
		this._instance = null;
		this.memory = new JSObjectSpace();
		this._closureDeallocator = null;
		this.tid = null;
		this.options = options || {};
		this.getDataView = () => {
			throw new Error("Please call setInstance() before using any JavaScriptKit APIs from Swift.");
		};
		this.getUint8Array = () => {
			throw new Error("Please call setInstance() before using any JavaScriptKit APIs from Swift.");
		};
		this.wasmMemory = null;
	}
	setInstance(instance) {
		this._instance = instance;
		const wasmMemory = instance.exports.memory;
		if (wasmMemory instanceof WebAssembly.Memory) {
			let cachedDataView = new DataView(wasmMemory.buffer);
			let cachedUint8Array = new Uint8Array(wasmMemory.buffer);
			if (Object.getPrototypeOf(wasmMemory.buffer).constructor.name === "SharedArrayBuffer") {
				this.getDataView = () => {
					if (cachedDataView.buffer !== wasmMemory.buffer) cachedDataView = new DataView(wasmMemory.buffer);
					return cachedDataView;
				};
				this.getUint8Array = () => {
					if (cachedUint8Array.buffer !== wasmMemory.buffer) cachedUint8Array = new Uint8Array(wasmMemory.buffer);
					return cachedUint8Array;
				};
			} else {
				this.getDataView = () => {
					if (cachedDataView.buffer.byteLength === 0) cachedDataView = new DataView(wasmMemory.buffer);
					return cachedDataView;
				};
				this.getUint8Array = () => {
					if (cachedUint8Array.byteLength === 0) cachedUint8Array = new Uint8Array(wasmMemory.buffer);
					return cachedUint8Array;
				};
			}
			this.wasmMemory = wasmMemory;
		} else throw new Error("instance.exports.memory is not a WebAssembly.Memory!?");
		if (typeof this.exports._start === "function") throw new Error(`JavaScriptKit supports only WASI reactor ABI.
                Please make sure you are building with:
                -Xswiftc -Xclang-linker -Xswiftc -mexec-model=reactor
                `);
		if (this.exports.swjs_library_version() != this.version) throw new Error(`The versions of JavaScriptKit are incompatible.
                WebAssembly runtime ${this.exports.swjs_library_version()} != JS runtime ${this.version}`);
	}
	main() {
		const instance = this.instance;
		try {
			if (typeof instance.exports.main === "function") instance.exports.main();
			else if (typeof instance.exports.__main_argc_argv === "function") instance.exports.__main_argc_argv(0, 0);
		} catch (error) {
			if (error instanceof UnsafeEventLoopYield) return;
			throw error;
		}
	}
	/**
	* Start a new thread with the given `tid` and `startArg`, which
	* is forwarded to the `wasi_thread_start` function.
	* This function is expected to be called from the spawned Web Worker thread.
	*/
	startThread(tid, startArg) {
		this.tid = tid;
		const instance = this.instance;
		try {
			if (typeof instance.exports.wasi_thread_start === "function") instance.exports.wasi_thread_start(tid, startArg);
			else throw new Error(`The WebAssembly module is not built for wasm32-unknown-wasip1-threads target.`);
		} catch (error) {
			if (error instanceof UnsafeEventLoopYield) return;
			throw error;
		}
	}
	get instance() {
		if (!this._instance) throw new Error("WebAssembly instance is not set yet");
		return this._instance;
	}
	get exports() {
		return this.instance.exports;
	}
	get closureDeallocator() {
		if (this._closureDeallocator) return this._closureDeallocator;
		if ((this.exports.swjs_library_features() & 1) != 0) this._closureDeallocator = new SwiftClosureDeallocator(this.exports);
		return this._closureDeallocator;
	}
	callHostFunction(host_func_id, line, file, args) {
		const argc = args.length;
		const argv = this.exports.swjs_prepare_host_function_call(argc);
		const memory = this.memory;
		const dataView = this.getDataView();
		for (let index = 0; index < args.length; index++) {
			const argument = args[index];
			const base = argv + 16 * index;
			write(argument, base, base + 4, base + 8, false, dataView, memory);
		}
		let output;
		const callback_func_ref = memory.retain((result) => {
			output = result;
		});
		if (this.exports.swjs_call_host_function(host_func_id, argv, argc, callback_func_ref)) throw new Error(`The JSClosure has been already released by Swift side. The closure is created at ${file}:${line} @${host_func_id}`);
		this.exports.swjs_cleanup_host_function_call(argv);
		return output;
	}
	get wasmImports() {
		let broker = null;
		const getMessageBroker = (threadChannel) => {
			var _a;
			if (broker) return broker;
			const itcInterface = new ITCInterface(this.memory);
			const newBroker = new MessageBroker((_a = this.tid) !== null && _a !== void 0 ? _a : -1, threadChannel, {
				onRequest: (message) => {
					let returnValue;
					try {
						returnValue = {
							ok: true,
							value: itcInterface[message.data.request.method](...message.data.request.parameters)
						};
					} catch (error) {
						returnValue = {
							ok: false,
							error: serializeError(error)
						};
					}
					const responseMessage = {
						type: "response",
						data: {
							sourceTid: message.data.sourceTid,
							context: message.data.context,
							response: returnValue
						}
					};
					try {
						newBroker.reply(responseMessage);
					} catch (error) {
						responseMessage.data.response = {
							ok: false,
							error: serializeError(/* @__PURE__ */ new TypeError(`Failed to serialize message: ${error}`))
						};
						newBroker.reply(responseMessage);
					}
				},
				onResponse: (message) => {
					if (message.data.response.ok) {
						const object = this.memory.retain(message.data.response.value.object);
						this.exports.swjs_receive_response(object, message.data.context);
					} else {
						const error = deserializeError(message.data.response.error);
						const errorObject = this.memory.retain(error);
						this.exports.swjs_receive_error(errorObject, message.data.context);
					}
				}
			});
			broker = newBroker;
			return newBroker;
		};
		return {
			swjs_set_prop: (ref, name, kind, payload1, payload2) => {
				const memory = this.memory;
				const obj = memory.getObject(ref);
				const key = memory.getObject(name);
				obj[key] = decode(kind, payload1, payload2, memory);
			},
			swjs_get_prop: (ref, name, payload1_ptr, payload2_ptr) => {
				const memory = this.memory;
				const result = memory.getObject(ref)[memory.getObject(name)];
				return writeAndReturnKindBits(result, payload1_ptr, payload2_ptr, false, this.getDataView(), this.memory);
			},
			swjs_set_subscript: (ref, index, kind, payload1, payload2) => {
				const memory = this.memory;
				const obj = memory.getObject(ref);
				obj[index] = decode(kind, payload1, payload2, memory);
			},
			swjs_get_subscript: (ref, index, payload1_ptr, payload2_ptr) => {
				const result = this.memory.getObject(ref)[index];
				return writeAndReturnKindBits(result, payload1_ptr, payload2_ptr, false, this.getDataView(), this.memory);
			},
			swjs_encode_string: (ref, bytes_ptr_result) => {
				const memory = this.memory;
				const bytes = this.textEncoder.encode(memory.getObject(ref));
				const bytes_ptr = memory.retain(bytes);
				this.getDataView().setUint32(bytes_ptr_result, bytes_ptr, true);
				return bytes.length;
			},
			swjs_decode_string: this.options.sharedMemory == true ? ((bytes_ptr, length) => {
				const bytes = this.getUint8Array().slice(bytes_ptr, bytes_ptr + length);
				const string = this.textDecoder.decode(bytes);
				return this.memory.retain(string);
			}) : ((bytes_ptr, length) => {
				const bytes = this.getUint8Array().subarray(bytes_ptr, bytes_ptr + length);
				const string = this.textDecoder.decode(bytes);
				return this.memory.retain(string);
			}),
			swjs_load_string: (ref, buffer) => {
				const bytes = this.memory.getObject(ref);
				this.getUint8Array().set(bytes, buffer);
			},
			swjs_call_function: (ref, argv, argc, payload1_ptr, payload2_ptr) => {
				const memory = this.memory;
				const func = memory.getObject(ref);
				let result = void 0;
				try {
					result = func(...decodeArray(argv, argc, this.getDataView(), memory));
				} catch (error) {
					return writeAndReturnKindBits(error, payload1_ptr, payload2_ptr, true, this.getDataView(), this.memory);
				}
				return writeAndReturnKindBits(result, payload1_ptr, payload2_ptr, false, this.getDataView(), this.memory);
			},
			swjs_call_function_no_catch: (ref, argv, argc, payload1_ptr, payload2_ptr) => {
				const memory = this.memory;
				return writeAndReturnKindBits(memory.getObject(ref)(...decodeArray(argv, argc, this.getDataView(), memory)), payload1_ptr, payload2_ptr, false, this.getDataView(), this.memory);
			},
			swjs_call_function_with_this: (obj_ref, func_ref, argv, argc, payload1_ptr, payload2_ptr) => {
				const memory = this.memory;
				const obj = memory.getObject(obj_ref);
				const func = memory.getObject(func_ref);
				let result;
				try {
					const args = decodeArray(argv, argc, this.getDataView(), memory);
					result = func.apply(obj, args);
				} catch (error) {
					return writeAndReturnKindBits(error, payload1_ptr, payload2_ptr, true, this.getDataView(), this.memory);
				}
				return writeAndReturnKindBits(result, payload1_ptr, payload2_ptr, false, this.getDataView(), this.memory);
			},
			swjs_call_function_with_this_no_catch: (obj_ref, func_ref, argv, argc, payload1_ptr, payload2_ptr) => {
				const memory = this.memory;
				const obj = memory.getObject(obj_ref);
				const func = memory.getObject(func_ref);
				let result = void 0;
				const args = decodeArray(argv, argc, this.getDataView(), memory);
				result = func.apply(obj, args);
				return writeAndReturnKindBits(result, payload1_ptr, payload2_ptr, false, this.getDataView(), this.memory);
			},
			swjs_call_new: (ref, argv, argc) => {
				const memory = this.memory;
				const instance = new (memory.getObject(ref))(...decodeArray(argv, argc, this.getDataView(), memory));
				return this.memory.retain(instance);
			},
			swjs_call_throwing_new: (ref, argv, argc, exception_kind_ptr, exception_payload1_ptr, exception_payload2_ptr) => {
				let memory = this.memory;
				const constructor = memory.getObject(ref);
				let result;
				try {
					result = new constructor(...decodeArray(argv, argc, this.getDataView(), memory));
				} catch (error) {
					write(error, exception_kind_ptr, exception_payload1_ptr, exception_payload2_ptr, true, this.getDataView(), this.memory);
					return -1;
				}
				memory = this.memory;
				write(null, exception_kind_ptr, exception_payload1_ptr, exception_payload2_ptr, false, this.getDataView(), memory);
				return memory.retain(result);
			},
			swjs_instanceof: (obj_ref, constructor_ref) => {
				const memory = this.memory;
				return memory.getObject(obj_ref) instanceof memory.getObject(constructor_ref);
			},
			swjs_value_equals: (lhs_ref, rhs_ref) => {
				const memory = this.memory;
				return memory.getObject(lhs_ref) == memory.getObject(rhs_ref);
			},
			swjs_create_function: (host_func_id, line, file) => {
				var _a;
				const fileString = this.memory.getObject(file);
				const func = (...args) => this.callHostFunction(host_func_id, line, fileString, args);
				const func_ref = this.memory.retain(func);
				(_a = this.closureDeallocator) === null || _a === void 0 || _a.track(func, host_func_id);
				return func_ref;
			},
			swjs_create_oneshot_function: (host_func_id, line, file) => {
				const fileString = this.memory.getObject(file);
				const func = (...args) => this.callHostFunction(host_func_id, line, fileString, args);
				return this.memory.retain(func);
			},
			swjs_create_typed_array: (constructor_ref, elementsPtr, length) => {
				const ArrayType = this.memory.getObject(constructor_ref);
				if (length == 0) return this.memory.retain(new ArrayType());
				const array = new ArrayType(this.wasmMemory.buffer, elementsPtr, length);
				return this.memory.retain(array.slice());
			},
			swjs_create_object: () => {
				return this.memory.retain({});
			},
			swjs_load_typed_array: (ref, buffer) => {
				const typedArray = this.memory.getObject(ref);
				const bytes = new Uint8Array(typedArray.buffer);
				this.getUint8Array().set(bytes, buffer);
			},
			swjs_release: (ref) => {
				this.memory.release(ref);
			},
			swjs_release_remote: (tid, ref) => {
				var _a;
				if (!this.options.threadChannel) throw new Error("threadChannel is not set in options given to SwiftRuntime. Please set it to release objects on remote threads.");
				getMessageBroker(this.options.threadChannel).request({
					type: "request",
					data: {
						sourceTid: (_a = this.tid) !== null && _a !== void 0 ? _a : MAIN_THREAD_TID,
						targetTid: tid,
						context: 0,
						request: {
							method: "release",
							parameters: [ref]
						}
					}
				});
			},
			swjs_i64_to_bigint: (value, signed) => {
				return this.memory.retain(signed ? value : BigInt.asUintN(64, value));
			},
			swjs_bigint_to_i64: (ref, signed) => {
				const object = this.memory.getObject(ref);
				if (typeof object !== "bigint") throw new Error(`Expected a BigInt, but got ${typeof object}`);
				if (signed) return object;
				else {
					if (object < BigInt(0)) return BigInt(0);
					return BigInt.asIntN(64, object);
				}
			},
			swjs_i64_to_bigint_slow: (lower, upper, signed) => {
				const value = BigInt.asUintN(32, BigInt(lower)) + (BigInt.asUintN(32, BigInt(upper)) << BigInt(32));
				return this.memory.retain(signed ? BigInt.asIntN(64, value) : BigInt.asUintN(64, value));
			},
			swjs_unsafe_event_loop_yield: () => {
				throw new UnsafeEventLoopYield();
			},
			swjs_send_job_to_main_thread: (unowned_job) => {
				this.postMessageToMainThread({
					type: "job",
					data: unowned_job
				});
			},
			swjs_listen_message_from_main_thread: () => {
				const threadChannel = this.options.threadChannel;
				if (!(threadChannel && "listenMessageFromMainThread" in threadChannel)) throw new Error("listenMessageFromMainThread is not set in options given to SwiftRuntime. Please set it to listen to wake events from the main thread.");
				const broker$1 = getMessageBroker(threadChannel);
				threadChannel.listenMessageFromMainThread((message) => {
					switch (message.type) {
						case "wake":
							this.exports.swjs_wake_worker_thread();
							break;
						case "request":
							broker$1.onReceivingRequest(message);
							break;
						case "response":
							broker$1.onReceivingResponse(message);
							break;
						default:
							const unknownMessage = message;
							throw new Error(`Unknown message type: ${unknownMessage}`);
					}
				});
			},
			swjs_wake_up_worker_thread: (tid) => {
				this.postMessageToWorkerThread(tid, { type: "wake" });
			},
			swjs_listen_message_from_worker_thread: (tid) => {
				const threadChannel = this.options.threadChannel;
				if (!(threadChannel && "listenMessageFromWorkerThread" in threadChannel)) throw new Error("listenMessageFromWorkerThread is not set in options given to SwiftRuntime. Please set it to listen to jobs from worker threads.");
				const broker$1 = getMessageBroker(threadChannel);
				threadChannel.listenMessageFromWorkerThread(tid, (message) => {
					switch (message.type) {
						case "job":
							this.exports.swjs_enqueue_main_job_from_worker(message.data);
							break;
						case "request":
							broker$1.onReceivingRequest(message);
							break;
						case "response":
							broker$1.onReceivingResponse(message);
							break;
						default:
							const unknownMessage = message;
							throw new Error(`Unknown message type: ${unknownMessage}`);
					}
				});
			},
			swjs_terminate_worker_thread: (tid) => {
				var _a;
				const threadChannel = this.options.threadChannel;
				if (threadChannel && "terminateWorkerThread" in threadChannel) (_a = threadChannel.terminateWorkerThread) === null || _a === void 0 || _a.call(threadChannel, tid);
			},
			swjs_get_worker_thread_id: () => {
				return this.tid || -1;
			},
			swjs_request_sending_object: (sending_object, transferring_objects, transferring_objects_count, object_source_tid, sending_context) => {
				var _a;
				if (!this.options.threadChannel) throw new Error("threadChannel is not set in options given to SwiftRuntime. Please set it to request transferring objects.");
				const broker$1 = getMessageBroker(this.options.threadChannel);
				const transferringObjects = decodeObjectRefs(transferring_objects, transferring_objects_count, this.getDataView());
				broker$1.request({
					type: "request",
					data: {
						sourceTid: (_a = this.tid) !== null && _a !== void 0 ? _a : MAIN_THREAD_TID,
						targetTid: object_source_tid,
						context: sending_context,
						request: {
							method: "send",
							parameters: [
								sending_object,
								transferringObjects,
								sending_context
							]
						}
					}
				});
			},
			swjs_request_sending_objects: (sending_objects, sending_objects_count, transferring_objects, transferring_objects_count, object_source_tid, sending_context) => {
				var _a;
				if (!this.options.threadChannel) throw new Error("threadChannel is not set in options given to SwiftRuntime. Please set it to request transferring objects.");
				const broker$1 = getMessageBroker(this.options.threadChannel);
				const dataView = this.getDataView();
				const sendingObjects = decodeObjectRefs(sending_objects, sending_objects_count, dataView);
				const transferringObjects = decodeObjectRefs(transferring_objects, transferring_objects_count, dataView);
				broker$1.request({
					type: "request",
					data: {
						sourceTid: (_a = this.tid) !== null && _a !== void 0 ? _a : MAIN_THREAD_TID,
						targetTid: object_source_tid,
						context: sending_context,
						request: {
							method: "sendObjects",
							parameters: [
								sendingObjects,
								transferringObjects,
								sending_context
							]
						}
					}
				});
			}
		};
	}
	postMessageToMainThread(message, transfer = []) {
		const threadChannel = this.options.threadChannel;
		if (!(threadChannel && "postMessageToMainThread" in threadChannel)) throw new Error("postMessageToMainThread is not set in options given to SwiftRuntime. Please set it to send messages to the main thread.");
		threadChannel.postMessageToMainThread(message, transfer);
	}
	postMessageToWorkerThread(tid, message, transfer = []) {
		const threadChannel = this.options.threadChannel;
		if (!(threadChannel && "postMessageToWorkerThread" in threadChannel)) throw new Error("postMessageToWorkerThread is not set in options given to SwiftRuntime. Please set it to send messages to worker threads.");
		threadChannel.postMessageToWorkerThread(tid, message, transfer);
	}
};
var UnsafeEventLoopYield = class extends Error {};

//#endregion
//#region src/generated/bridge-js.js
async function createInstantiator(options, swift) {
	let instance;
	let memory;
	let setException;
	const textDecoder = new TextDecoder("utf-8");
	const textEncoder = new TextEncoder("utf-8");
	let tmpRetString;
	let tmpRetBytes;
	let tmpRetException;
	let tmpRetOptionalInt;
	let tmpRetOptionalFloat;
	let tmpRetOptionalDouble;
	let tmpRetOptionalHeapObject;
	let strStack = [];
	let i32Stack = [];
	let f32Stack = [];
	let f64Stack = [];
	let ptrStack = [];
	let tmpStructCleanups = [];
	let bjs = null;
	const swiftClosureRegistry = typeof FinalizationRegistry === "undefined" ? {
		register: () => {},
		unregister: () => {}
	} : new FinalizationRegistry((state) => {
		if (state.unregistered) return;
		instance?.exports?.bjs_release_swift_closure(state.pointer);
	});
	const makeClosure = (pointer, file, line, func) => {
		const state = {
			pointer,
			file,
			line,
			unregistered: false
		};
		const real = (...args) => {
			if (state.unregistered) {
				const bytes = new Uint8Array(memory.buffer, state.file);
				let length = 0;
				while (bytes[length] !== 0) length += 1;
				const fileID = textDecoder.decode(bytes.subarray(0, length));
				throw new Error(`Attempted to call a released JSTypedClosure created at ${fileID}:${state.line}`);
			}
			return func(...args);
		};
		real.__unregister = () => {
			if (state.unregistered) return;
			state.unregistered = true;
			swiftClosureRegistry.unregister(state);
		};
		swiftClosureRegistry.register(real, state, state);
		return swift.memory.retain(real);
	};
	return {
		addImports: (importObject, importsContext) => {
			bjs = {};
			importObject["bjs"] = bjs;
			bjs["swift_js_return_string"] = function(ptr, len) {
				const bytes = new Uint8Array(memory.buffer, ptr, len);
				tmpRetString = textDecoder.decode(bytes);
			};
			bjs["swift_js_init_memory"] = function(sourceId, bytesPtr) {
				const source = swift.memory.getObject(sourceId);
				swift.memory.release(sourceId);
				new Uint8Array(memory.buffer, bytesPtr).set(source);
			};
			bjs["swift_js_make_js_string"] = function(ptr, len) {
				const bytes = new Uint8Array(memory.buffer, ptr, len);
				return swift.memory.retain(textDecoder.decode(bytes));
			};
			bjs["swift_js_init_memory_with_result"] = function(ptr, len) {
				new Uint8Array(memory.buffer, ptr, len).set(tmpRetBytes);
				tmpRetBytes = void 0;
			};
			bjs["swift_js_throw"] = function(id) {
				tmpRetException = swift.memory.retainByRef(id);
			};
			bjs["swift_js_retain"] = function(id) {
				return swift.memory.retainByRef(id);
			};
			bjs["swift_js_release"] = function(id) {
				swift.memory.release(id);
			};
			bjs["swift_js_push_i32"] = function(v) {
				i32Stack.push(v | 0);
			};
			bjs["swift_js_push_f32"] = function(v) {
				f32Stack.push(Math.fround(v));
			};
			bjs["swift_js_push_f64"] = function(v) {
				f64Stack.push(v);
			};
			bjs["swift_js_push_string"] = function(ptr, len) {
				const bytes = new Uint8Array(memory.buffer, ptr, len);
				const value = textDecoder.decode(bytes);
				strStack.push(value);
			};
			bjs["swift_js_pop_i32"] = function() {
				return i32Stack.pop();
			};
			bjs["swift_js_pop_f32"] = function() {
				return f32Stack.pop();
			};
			bjs["swift_js_pop_f64"] = function() {
				return f64Stack.pop();
			};
			bjs["swift_js_push_pointer"] = function(pointer) {
				ptrStack.push(pointer);
			};
			bjs["swift_js_pop_pointer"] = function() {
				return ptrStack.pop();
			};
			bjs["swift_js_struct_cleanup"] = function(cleanupId) {
				if (cleanupId === 0) return;
				const index = (cleanupId | 0) - 1;
				const cleanup = tmpStructCleanups[index];
				tmpStructCleanups[index] = null;
				if (cleanup) cleanup();
				while (tmpStructCleanups.length > 0 && tmpStructCleanups[tmpStructCleanups.length - 1] == null) tmpStructCleanups.pop();
			};
			bjs["swift_js_return_optional_bool"] = function(isSome, value) {
				if (isSome === 0) {}
			};
			bjs["swift_js_return_optional_int"] = function(isSome, value) {
				if (isSome === 0) tmpRetOptionalInt = null;
				else tmpRetOptionalInt = value | 0;
			};
			bjs["swift_js_return_optional_float"] = function(isSome, value) {
				if (isSome === 0) tmpRetOptionalFloat = null;
				else tmpRetOptionalFloat = Math.fround(value);
			};
			bjs["swift_js_return_optional_double"] = function(isSome, value) {
				if (isSome === 0) tmpRetOptionalDouble = null;
				else tmpRetOptionalDouble = value;
			};
			bjs["swift_js_return_optional_string"] = function(isSome, ptr, len) {
				if (isSome === 0) tmpRetString = null;
				else {
					const bytes = new Uint8Array(memory.buffer, ptr, len);
					tmpRetString = textDecoder.decode(bytes);
				}
			};
			bjs["swift_js_return_optional_object"] = function(isSome, objectId) {
				if (isSome === 0) tmpRetString = null;
				else tmpRetString = swift.memory.getObject(objectId);
			};
			bjs["swift_js_return_optional_heap_object"] = function(isSome, pointer) {
				if (isSome === 0) tmpRetOptionalHeapObject = null;
				else tmpRetOptionalHeapObject = pointer;
			};
			bjs["swift_js_get_optional_int_presence"] = function() {
				return tmpRetOptionalInt != null ? 1 : 0;
			};
			bjs["swift_js_get_optional_int_value"] = function() {
				const value = tmpRetOptionalInt;
				tmpRetOptionalInt = void 0;
				return value;
			};
			bjs["swift_js_get_optional_string"] = function() {
				const str = tmpRetString;
				tmpRetString = void 0;
				if (str == null) return -1;
				else {
					const bytes = textEncoder.encode(str);
					tmpRetBytes = bytes;
					return bytes.length;
				}
			};
			bjs["swift_js_get_optional_float_presence"] = function() {
				return tmpRetOptionalFloat != null ? 1 : 0;
			};
			bjs["swift_js_get_optional_float_value"] = function() {
				const value = tmpRetOptionalFloat;
				tmpRetOptionalFloat = void 0;
				return value;
			};
			bjs["swift_js_get_optional_double_presence"] = function() {
				return tmpRetOptionalDouble != null ? 1 : 0;
			};
			bjs["swift_js_get_optional_double_value"] = function() {
				const value = tmpRetOptionalDouble;
				tmpRetOptionalDouble = void 0;
				return value;
			};
			bjs["swift_js_get_optional_heap_object_pointer"] = function() {
				const pointer = tmpRetOptionalHeapObject;
				tmpRetOptionalHeapObject = void 0;
				return pointer || 0;
			};
			bjs["swift_js_closure_unregister"] = function(funcRef) {};
			bjs["swift_js_closure_unregister"] = function(funcRef) {
				swift.memory.getObject(funcRef).__unregister();
			};
			bjs["invoke_js_callback_BrowserInterop_14BrowserInteropSd_y"] = function(callbackId, param0) {
				try {
					swift.memory.getObject(callbackId)(param0);
				} catch (error) {
					setException(error);
				}
			};
			bjs["make_swift_closure_BrowserInterop_14BrowserInteropSd_y"] = function(boxPtr, file, line) {
				const lower_closure_BrowserInterop_14BrowserInteropSd_y = function(param0) {
					instance.exports.invoke_swift_closure_BrowserInterop_14BrowserInteropSd_y(boxPtr, param0);
					if (tmpRetException) {
						const error = swift.memory.getObject(tmpRetException);
						swift.memory.release(tmpRetException);
						tmpRetException = void 0;
						throw error;
					}
				};
				return makeClosure(boxPtr, file, line, lower_closure_BrowserInterop_14BrowserInteropSd_y);
			};
			bjs["invoke_js_callback_BrowserInterop_14BrowserInteropy_y"] = function(callbackId) {
				try {
					swift.memory.getObject(callbackId)();
				} catch (error) {
					setException(error);
				}
			};
			bjs["make_swift_closure_BrowserInterop_14BrowserInteropy_y"] = function(boxPtr, file, line) {
				const lower_closure_BrowserInterop_14BrowserInteropy_y = function() {
					instance.exports.invoke_swift_closure_BrowserInterop_14BrowserInteropy_y(boxPtr);
					if (tmpRetException) {
						const error = swift.memory.getObject(tmpRetException);
						swift.memory.release(tmpRetException);
						tmpRetException = void 0;
						throw error;
					}
				};
				return makeClosure(boxPtr, file, line, lower_closure_BrowserInterop_14BrowserInteropy_y);
			};
			const BrowserInterop = importObject["BrowserInterop"] = importObject["BrowserInterop"] || {};
			BrowserInterop["bjs_JSDocument_body_get"] = function bjs_JSDocument_body_get(self$1) {
				try {
					let ret = swift.memory.getObject(self$1).body;
					return swift.memory.retain(ret);
				} catch (error) {
					setException(error);
					return 0;
				}
			};
			BrowserInterop["bjs_JSDocument_createElement"] = function bjs_JSDocument_createElement(self$1, tagName) {
				try {
					const tagNameObject = swift.memory.getObject(tagName);
					swift.memory.release(tagName);
					let ret = swift.memory.getObject(self$1).createElement(tagNameObject);
					return swift.memory.retain(ret);
				} catch (error) {
					setException(error);
					return 0;
				}
			};
			BrowserInterop["bjs_JSDocument_createTextNode"] = function bjs_JSDocument_createTextNode(self$1, text) {
				try {
					const textObject = swift.memory.getObject(text);
					swift.memory.release(text);
					let ret = swift.memory.getObject(self$1).createTextNode(textObject);
					return swift.memory.retain(ret);
				} catch (error) {
					setException(error);
					return 0;
				}
			};
			BrowserInterop["bjs_JSDocument_querySelector"] = function bjs_JSDocument_querySelector(self$1, selector) {
				try {
					const selectorObject = swift.memory.getObject(selector);
					swift.memory.release(selector);
					let ret = swift.memory.getObject(self$1).querySelector(selectorObject);
					return swift.memory.retain(ret);
				} catch (error) {
					setException(error);
					return 0;
				}
			};
			BrowserInterop["bjs_JSDocument_addEventListener"] = function bjs_JSDocument_addEventListener(self$1, type, listener) {
				try {
					const typeObject = swift.memory.getObject(type);
					swift.memory.release(type);
					swift.memory.getObject(self$1).addEventListener(typeObject, swift.memory.getObject(listener));
				} catch (error) {
					setException(error);
				}
			};
			BrowserInterop["bjs_JSDocument_removeEventListener"] = function bjs_JSDocument_removeEventListener(self$1, type, listener) {
				try {
					const typeObject = swift.memory.getObject(type);
					swift.memory.release(type);
					swift.memory.getObject(self$1).removeEventListener(typeObject, swift.memory.getObject(listener));
				} catch (error) {
					setException(error);
				}
			};
			BrowserInterop["bjs_JSWindow_scrollX_get"] = function bjs_JSWindow_scrollX_get(self$1) {
				try {
					return swift.memory.getObject(self$1).scrollX;
				} catch (error) {
					setException(error);
					return 0;
				}
			};
			BrowserInterop["bjs_JSWindow_scrollY_get"] = function bjs_JSWindow_scrollY_get(self$1) {
				try {
					return swift.memory.getObject(self$1).scrollY;
				} catch (error) {
					setException(error);
					return 0;
				}
			};
			BrowserInterop["bjs_JSWindow_getComputedStyle"] = function bjs_JSWindow_getComputedStyle(self$1, element) {
				try {
					let ret = swift.memory.getObject(self$1).getComputedStyle(swift.memory.getObject(element));
					return swift.memory.retain(ret);
				} catch (error) {
					setException(error);
					return 0;
				}
			};
			BrowserInterop["bjs_JSPerformance_now"] = function bjs_JSPerformance_now(self$1) {
				try {
					return swift.memory.getObject(self$1).now();
				} catch (error) {
					setException(error);
					return 0;
				}
			};
			BrowserInterop["bjs_JSNode_textContent_get"] = function bjs_JSNode_textContent_get(self$1) {
				try {
					let ret = swift.memory.getObject(self$1).textContent;
					if (ret != null) tmpRetString = ret;
					else tmpRetString = null;
				} catch (error) {
					setException(error);
				}
			};
			BrowserInterop["bjs_JSNode_textContent_set"] = function bjs_JSNode_textContent_set(self$1, newValueIsSome, newValueWrappedValue) {
				try {
					let obj;
					if (newValueIsSome) {
						obj = swift.memory.getObject(newValueWrappedValue);
						swift.memory.release(newValueWrappedValue);
					}
					swift.memory.getObject(self$1).textContent = newValueIsSome ? obj : null;
				} catch (error) {
					setException(error);
				}
			};
			BrowserInterop["bjs_JSElement_style_get"] = function bjs_JSElement_style_get(self$1) {
				try {
					let ret = swift.memory.getObject(self$1).style;
					return swift.memory.retain(ret);
				} catch (error) {
					setException(error);
					return 0;
				}
			};
			BrowserInterop["bjs_JSElement_textContent_get"] = function bjs_JSElement_textContent_get(self$1) {
				try {
					let ret = swift.memory.getObject(self$1).textContent;
					if (ret != null) tmpRetString = ret;
					else tmpRetString = null;
				} catch (error) {
					setException(error);
				}
			};
			BrowserInterop["bjs_JSElement_offsetParent_get"] = function bjs_JSElement_offsetParent_get(self$1) {
				try {
					let ret = swift.memory.getObject(self$1).offsetParent;
					return swift.memory.retain(ret);
				} catch (error) {
					setException(error);
					return 0;
				}
			};
			BrowserInterop["bjs_JSElement_textContent_set"] = function bjs_JSElement_textContent_set(self$1, newValueIsSome, newValueWrappedValue) {
				try {
					let obj;
					if (newValueIsSome) {
						obj = swift.memory.getObject(newValueWrappedValue);
						swift.memory.release(newValueWrappedValue);
					}
					swift.memory.getObject(self$1).textContent = newValueIsSome ? obj : null;
				} catch (error) {
					setException(error);
				}
			};
			BrowserInterop["bjs_JSElement_setAttribute"] = function bjs_JSElement_setAttribute(self$1, name, value) {
				try {
					const nameObject = swift.memory.getObject(name);
					swift.memory.release(name);
					const valueObject = swift.memory.getObject(value);
					swift.memory.release(value);
					swift.memory.getObject(self$1).setAttribute(nameObject, valueObject);
				} catch (error) {
					setException(error);
				}
			};
			BrowserInterop["bjs_JSElement_removeAttribute"] = function bjs_JSElement_removeAttribute(self$1, name) {
				try {
					const nameObject = swift.memory.getObject(name);
					swift.memory.release(name);
					swift.memory.getObject(self$1).removeAttribute(nameObject);
				} catch (error) {
					setException(error);
				}
			};
			BrowserInterop["bjs_JSElement_appendChild"] = function bjs_JSElement_appendChild(self$1, child) {
				try {
					swift.memory.getObject(self$1).appendChild(swift.memory.getObject(child));
				} catch (error) {
					setException(error);
				}
			};
			BrowserInterop["bjs_JSElement_removeChild"] = function bjs_JSElement_removeChild(self$1, child) {
				try {
					swift.memory.getObject(self$1).removeChild(swift.memory.getObject(child));
				} catch (error) {
					setException(error);
				}
			};
			BrowserInterop["bjs_JSElement_getBoundingClientRect"] = function bjs_JSElement_getBoundingClientRect(self$1) {
				try {
					let ret = swift.memory.getObject(self$1).getBoundingClientRect();
					return swift.memory.retain(ret);
				} catch (error) {
					setException(error);
					return 0;
				}
			};
			BrowserInterop["bjs_JSElement_addEventListener"] = function bjs_JSElement_addEventListener(self$1, type, listener) {
				try {
					const typeObject = swift.memory.getObject(type);
					swift.memory.release(type);
					swift.memory.getObject(self$1).addEventListener(typeObject, swift.memory.getObject(listener));
				} catch (error) {
					setException(error);
				}
			};
			BrowserInterop["bjs_JSElement_removeEventListener"] = function bjs_JSElement_removeEventListener(self$1, type, listener) {
				try {
					const typeObject = swift.memory.getObject(type);
					swift.memory.release(type);
					swift.memory.getObject(self$1).removeEventListener(typeObject, swift.memory.getObject(listener));
				} catch (error) {
					setException(error);
				}
			};
			BrowserInterop["bjs_JSElement_focus"] = function bjs_JSElement_focus(self$1) {
				try {
					swift.memory.getObject(self$1).focus();
				} catch (error) {
					setException(error);
				}
			};
			BrowserInterop["bjs_JSElement_blur"] = function bjs_JSElement_blur(self$1) {
				try {
					swift.memory.getObject(self$1).blur();
				} catch (error) {
					setException(error);
				}
			};
			BrowserInterop["bjs_JSElement_animate"] = function bjs_JSElement_animate(self$1, keyframes, options$1) {
				try {
					let ret = swift.memory.getObject(self$1).animate(swift.memory.getObject(keyframes), swift.memory.getObject(options$1));
					return swift.memory.retain(ret);
				} catch (error) {
					setException(error);
					return 0;
				}
			};
			BrowserInterop["bjs_JSCSSStyleDeclaration_getPropertyValue"] = function bjs_JSCSSStyleDeclaration_getPropertyValue(self$1, name) {
				try {
					const nameObject = swift.memory.getObject(name);
					swift.memory.release(name);
					let ret = swift.memory.getObject(self$1).getPropertyValue(nameObject);
					tmpRetBytes = textEncoder.encode(ret);
					return tmpRetBytes.length;
				} catch (error) {
					setException(error);
				}
			};
			BrowserInterop["bjs_JSCSSStyleDeclaration_setProperty"] = function bjs_JSCSSStyleDeclaration_setProperty(self$1, name, value) {
				try {
					const nameObject = swift.memory.getObject(name);
					swift.memory.release(name);
					const valueObject = swift.memory.getObject(value);
					swift.memory.release(value);
					swift.memory.getObject(self$1).setProperty(nameObject, valueObject);
				} catch (error) {
					setException(error);
				}
			};
			BrowserInterop["bjs_JSCSSStyleDeclaration_removeProperty"] = function bjs_JSCSSStyleDeclaration_removeProperty(self$1, name) {
				try {
					const nameObject = swift.memory.getObject(name);
					swift.memory.release(name);
					swift.memory.getObject(self$1).removeProperty(nameObject);
				} catch (error) {
					setException(error);
				}
			};
			BrowserInterop["bjs_JSDOMRect_x_get"] = function bjs_JSDOMRect_x_get(self$1) {
				try {
					return swift.memory.getObject(self$1).x;
				} catch (error) {
					setException(error);
					return 0;
				}
			};
			BrowserInterop["bjs_JSDOMRect_y_get"] = function bjs_JSDOMRect_y_get(self$1) {
				try {
					return swift.memory.getObject(self$1).y;
				} catch (error) {
					setException(error);
					return 0;
				}
			};
			BrowserInterop["bjs_JSDOMRect_width_get"] = function bjs_JSDOMRect_width_get(self$1) {
				try {
					return swift.memory.getObject(self$1).width;
				} catch (error) {
					setException(error);
					return 0;
				}
			};
			BrowserInterop["bjs_JSDOMRect_height_get"] = function bjs_JSDOMRect_height_get(self$1) {
				try {
					return swift.memory.getObject(self$1).height;
				} catch (error) {
					setException(error);
					return 0;
				}
			};
			BrowserInterop["bjs_JSAnimation_effect_get"] = function bjs_JSAnimation_effect_get(self$1) {
				try {
					let ret = swift.memory.getObject(self$1).effect;
					return swift.memory.retain(ret);
				} catch (error) {
					setException(error);
					return 0;
				}
			};
			BrowserInterop["bjs_JSAnimation_currentTime_set"] = function bjs_JSAnimation_currentTime_set(self$1, newValue) {
				try {
					swift.memory.getObject(self$1).currentTime = newValue;
				} catch (error) {
					setException(error);
				}
			};
			BrowserInterop["bjs_JSAnimation_onfinish_set"] = function bjs_JSAnimation_onfinish_set(self$1, newValueIsSome, newValueWrappedValue) {
				try {
					swift.memory.getObject(self$1).onfinish = newValueIsSome ? swift.memory.getObject(newValueWrappedValue) : null;
				} catch (error) {
					setException(error);
				}
			};
			BrowserInterop["bjs_JSAnimation_persist"] = function bjs_JSAnimation_persist(self$1) {
				try {
					swift.memory.getObject(self$1).persist();
				} catch (error) {
					setException(error);
				}
			};
			BrowserInterop["bjs_JSAnimation_pause"] = function bjs_JSAnimation_pause(self$1) {
				try {
					swift.memory.getObject(self$1).pause();
				} catch (error) {
					setException(error);
				}
			};
			BrowserInterop["bjs_JSAnimation_play"] = function bjs_JSAnimation_play(self$1) {
				try {
					swift.memory.getObject(self$1).play();
				} catch (error) {
					setException(error);
				}
			};
			BrowserInterop["bjs_JSAnimation_cancel"] = function bjs_JSAnimation_cancel(self$1) {
				try {
					swift.memory.getObject(self$1).cancel();
				} catch (error) {
					setException(error);
				}
			};
			BrowserInterop["bjs_JSAnimationEffect_setKeyframes"] = function bjs_JSAnimationEffect_setKeyframes(self$1, keyframes) {
				try {
					swift.memory.getObject(self$1).setKeyframes(swift.memory.getObject(keyframes));
				} catch (error) {
					setException(error);
				}
			};
			BrowserInterop["bjs_JSAnimationEffect_updateTiming"] = function bjs_JSAnimationEffect_updateTiming(self$1, timing) {
				try {
					swift.memory.getObject(self$1).updateTiming(swift.memory.getObject(timing));
				} catch (error) {
					setException(error);
				}
			};
			BrowserInterop["bjs_JSEvent_type_get"] = function bjs_JSEvent_type_get(self$1) {
				try {
					let ret = swift.memory.getObject(self$1).type;
					tmpRetBytes = textEncoder.encode(ret);
					return tmpRetBytes.length;
				} catch (error) {
					setException(error);
				}
			};
			BrowserInterop["bjs_JSEvent_target_get"] = function bjs_JSEvent_target_get(self$1) {
				try {
					let ret = swift.memory.getObject(self$1).target;
					return swift.memory.retain(ret);
				} catch (error) {
					setException(error);
					return 0;
				}
			};
			BrowserInterop["bjs_JSKeyboardEvent_key_get"] = function bjs_JSKeyboardEvent_key_get(self$1) {
				try {
					let ret = swift.memory.getObject(self$1).key;
					tmpRetBytes = textEncoder.encode(ret);
					return tmpRetBytes.length;
				} catch (error) {
					setException(error);
				}
			};
			BrowserInterop["bjs_JSMouseEvent_altKey_get"] = function bjs_JSMouseEvent_altKey_get(self$1) {
				try {
					return swift.memory.getObject(self$1).altKey ? 1 : 0;
				} catch (error) {
					setException(error);
					return 0;
				}
			};
			BrowserInterop["bjs_JSMouseEvent_button_get"] = function bjs_JSMouseEvent_button_get(self$1) {
				try {
					return swift.memory.getObject(self$1).button;
				} catch (error) {
					setException(error);
					return 0;
				}
			};
			BrowserInterop["bjs_JSMouseEvent_buttons_get"] = function bjs_JSMouseEvent_buttons_get(self$1) {
				try {
					return swift.memory.getObject(self$1).buttons;
				} catch (error) {
					setException(error);
					return 0;
				}
			};
			BrowserInterop["bjs_JSMouseEvent_clientX_get"] = function bjs_JSMouseEvent_clientX_get(self$1) {
				try {
					return swift.memory.getObject(self$1).clientX;
				} catch (error) {
					setException(error);
					return 0;
				}
			};
			BrowserInterop["bjs_JSMouseEvent_clientY_get"] = function bjs_JSMouseEvent_clientY_get(self$1) {
				try {
					return swift.memory.getObject(self$1).clientY;
				} catch (error) {
					setException(error);
					return 0;
				}
			};
			BrowserInterop["bjs_JSMouseEvent_ctrlKey_get"] = function bjs_JSMouseEvent_ctrlKey_get(self$1) {
				try {
					return swift.memory.getObject(self$1).ctrlKey ? 1 : 0;
				} catch (error) {
					setException(error);
					return 0;
				}
			};
			BrowserInterop["bjs_JSMouseEvent_metaKey_get"] = function bjs_JSMouseEvent_metaKey_get(self$1) {
				try {
					return swift.memory.getObject(self$1).metaKey ? 1 : 0;
				} catch (error) {
					setException(error);
					return 0;
				}
			};
			BrowserInterop["bjs_JSMouseEvent_movementX_get"] = function bjs_JSMouseEvent_movementX_get(self$1) {
				try {
					return swift.memory.getObject(self$1).movementX;
				} catch (error) {
					setException(error);
					return 0;
				}
			};
			BrowserInterop["bjs_JSMouseEvent_movementY_get"] = function bjs_JSMouseEvent_movementY_get(self$1) {
				try {
					return swift.memory.getObject(self$1).movementY;
				} catch (error) {
					setException(error);
					return 0;
				}
			};
			BrowserInterop["bjs_JSMouseEvent_offsetX_get"] = function bjs_JSMouseEvent_offsetX_get(self$1) {
				try {
					return swift.memory.getObject(self$1).offsetX;
				} catch (error) {
					setException(error);
					return 0;
				}
			};
			BrowserInterop["bjs_JSMouseEvent_offsetY_get"] = function bjs_JSMouseEvent_offsetY_get(self$1) {
				try {
					return swift.memory.getObject(self$1).offsetY;
				} catch (error) {
					setException(error);
					return 0;
				}
			};
			BrowserInterop["bjs_JSMouseEvent_pageX_get"] = function bjs_JSMouseEvent_pageX_get(self$1) {
				try {
					return swift.memory.getObject(self$1).pageX;
				} catch (error) {
					setException(error);
					return 0;
				}
			};
			BrowserInterop["bjs_JSMouseEvent_pageY_get"] = function bjs_JSMouseEvent_pageY_get(self$1) {
				try {
					return swift.memory.getObject(self$1).pageY;
				} catch (error) {
					setException(error);
					return 0;
				}
			};
			BrowserInterop["bjs_JSMouseEvent_screenX_get"] = function bjs_JSMouseEvent_screenX_get(self$1) {
				try {
					return swift.memory.getObject(self$1).screenX;
				} catch (error) {
					setException(error);
					return 0;
				}
			};
			BrowserInterop["bjs_JSMouseEvent_screenY_get"] = function bjs_JSMouseEvent_screenY_get(self$1) {
				try {
					return swift.memory.getObject(self$1).screenY;
				} catch (error) {
					setException(error);
					return 0;
				}
			};
			BrowserInterop["bjs_JSMouseEvent_shiftKey_get"] = function bjs_JSMouseEvent_shiftKey_get(self$1) {
				try {
					return swift.memory.getObject(self$1).shiftKey ? 1 : 0;
				} catch (error) {
					setException(error);
					return 0;
				}
			};
			BrowserInterop["bjs_JSInputEvent_data_get"] = function bjs_JSInputEvent_data_get(self$1) {
				try {
					let ret = swift.memory.getObject(self$1).data;
					if (ret != null) tmpRetString = ret;
					else tmpRetString = null;
				} catch (error) {
					setException(error);
				}
			};
			BrowserInterop["bjs_JSInputEvent_target_get"] = function bjs_JSInputEvent_target_get(self$1) {
				try {
					let ret = swift.memory.getObject(self$1).target;
					return swift.memory.retain(ret);
				} catch (error) {
					setException(error);
					return 0;
				}
			};
			BrowserInterop["bjs_window_get"] = function bjs_window_get() {
				try {
					let ret = globalThis.window;
					return swift.memory.retain(ret);
				} catch (error) {
					setException(error);
					return 0;
				}
			};
			BrowserInterop["bjs_document_get"] = function bjs_document_get() {
				try {
					let ret = globalThis.document;
					return swift.memory.retain(ret);
				} catch (error) {
					setException(error);
					return 0;
				}
			};
			BrowserInterop["bjs_performance_get"] = function bjs_performance_get() {
				try {
					let ret = globalThis.performance;
					return swift.memory.retain(ret);
				} catch (error) {
					setException(error);
					return 0;
				}
			};
			BrowserInterop["bjs_requestAnimationFrame"] = function bjs_requestAnimationFrame(callback) {
				try {
					return globalThis.requestAnimationFrame(swift.memory.getObject(callback));
				} catch (error) {
					setException(error);
					return 0;
				}
			};
			BrowserInterop["bjs_cancelAnimationFrame"] = function bjs_cancelAnimationFrame(handle) {
				try {
					globalThis.cancelAnimationFrame(handle);
				} catch (error) {
					setException(error);
				}
			};
			BrowserInterop["bjs_queueMicrotask"] = function bjs_queueMicrotask(callback) {
				try {
					globalThis.queueMicrotask(swift.memory.getObject(callback));
				} catch (error) {
					setException(error);
				}
			};
			BrowserInterop["bjs_setTimeout"] = function bjs_setTimeout(callback, timeout) {
				try {
					globalThis.setTimeout(swift.memory.getObject(callback), timeout);
				} catch (error) {
					setException(error);
				}
			};
		},
		setInstance: (i) => {
			instance = i;
			memory = instance.exports.memory;
			setException = (error) => {
				instance.exports._swift_js_exception.value = swift.memory.retain(error);
			};
		},
		createExports: (instance$1) => {
			swift.memory.heap;
			return {};
		}
	};
}

//#endregion
//#region src/index.ts
/**
* Runs an ElementaryUI application.
*
* This function bootstraps a JavaScriptKit SwiftRuntime and WASI shim,
* then runs the application by calling Swift's main entry point.
*
* @param initializer - A function that receives WebAssembly imports and returns a WebAssembly instance.
* @returns A promise that resolves when initialization is complete and the Swift application has started.
*/
async function runApplication(initializer) {
	const wasi = createDefaultWASI();
	const swiftRuntime = new SwiftRuntime();
	let instance = null;
	const instantiator = await createInstantiator({ imports: {} }, swiftRuntime);
	const importsObject = {
		javascript_kit: swiftRuntime.wasmImports,
		wasi_snapshot_preview1: wasi.wasiImport
	};
	instantiator.addImports(importsObject);
	instance = await initializer(importsObject);
	swiftRuntime.setInstance(instance);
	instantiator.setInstance(instance);
	wasi.initialize(instance);
	swiftRuntime.main();
}

//#endregion
export { runApplication };