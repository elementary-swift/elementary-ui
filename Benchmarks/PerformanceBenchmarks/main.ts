import "bootstrap/dist/css/bootstrap.min.css";
import "./main.css";
import { init } from "virtual:swift-wasm?js";

await init();

document.getElementById("app")?.setAttribute("data-ready", "true");
