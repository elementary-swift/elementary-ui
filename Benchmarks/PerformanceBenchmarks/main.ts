import "bootstrap/dist/css/bootstrap.min.css";
import "./main.css";
import { runApplication } from "elementary-ui-browser-runtime";
import appInit from "virtual:swift-wasm?init&product=Benchmark";

await runApplication(appInit);

document.getElementById("app")?.setAttribute("data-ready", "true");
