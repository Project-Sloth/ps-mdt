import { mount } from "svelte";
import "material-icons/iconfont/filled.css";
import "@/styles/tailwind.css";
import "./styles/variables.css";
import "./styles/globals.css";
import App from "./App.svelte";

const app = mount(App, {
	target: document.getElementById("app")!,
});

export default app;
