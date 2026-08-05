import { getPermissionMeta } from "../constants/management";

/**
 * Marks a control as locked and explains why on hover.
 *
 * Two constraints shape this. First, a `disabled` button fires no mouse events
 * in Chromium, so the hint would never appear — the control is left enabled and
 * clicks are swallowed in the capture phase instead, with aria-disabled telling
 * assistive tech the truth. Second, CEF ignores the native `title` attribute
 * entirely, so the tooltip is a real element appended to <body> and positioned
 * fixed, the same approach the sidebar uses.
 *
 * Pass the permission key to lock the control, or null/undefined to leave it
 * alone — so a call site reads:
 *
 *   <button use:permissionHint={canClose ? null : "warrants_close"} …>
 */
export function permissionHint(node: HTMLElement, key: string | null | undefined) {
	let current = key;
	let tip: HTMLDivElement | null = null;

	function text(): { label: string; description: string } | null {
		if (!current) return null;
		const meta = getPermissionMeta(current);
		if (!meta) return { label: "Not available at your rank", description: "" };
		return { label: meta.label, description: meta.description };
	}

	function place(event: MouseEvent) {
		if (!tip) return;
		const box = tip.getBoundingClientRect();
		let x = event.clientX + 14;
		let y = event.clientY + 16;
		if (x + box.width > window.innerWidth - 4) x = event.clientX - box.width - 14;
		if (y + box.height > window.innerHeight - 4) y = event.clientY - box.height - 16;
		tip.style.left = `${Math.max(4, x)}px`;
		tip.style.top = `${Math.max(4, y)}px`;
	}

	function show(event: MouseEvent) {
		const content = text();
		if (!content || tip) return;

		tip = document.createElement("div");
		tip.style.cssText =
			"position:fixed;z-index:99999;max-width:250px;background:#111113;" +
			"border:1px solid rgba(255,255,255,0.12);border-left:2px solid rgba(245,158,11,0.7);" +
			"border-radius:5px;padding:8px 10px;box-shadow:0 8px 24px rgba(0,0,0,0.6);" +
			"pointer-events:none;font-size:11px;line-height:1.45;";

		const eyebrow = document.createElement("div");
		eyebrow.textContent = "Requires clearance";
		eyebrow.style.cssText =
			"font-size:9px;font-weight:600;letter-spacing:0.12em;text-transform:uppercase;" +
			"color:rgba(245,158,11,0.7);margin-bottom:3px;";

		const label = document.createElement("div");
		label.textContent = content.label;
		label.style.cssText = "font-weight:500;color:rgba(255,255,255,0.92);";

		tip.append(eyebrow, label);

		if (content.description) {
			const desc = document.createElement("div");
			desc.textContent = content.description;
			desc.style.cssText = "color:rgba(255,255,255,0.45);margin-top:2px;";
			tip.append(desc);
		}

		document.body.appendChild(tip);
		place(event);
	}

	function move(event: MouseEvent) {
		if (tip) place(event);
	}

	function hide() {
		tip?.remove();
		tip = null;
	}

	/** Capture phase: the control's own handler must never run while locked. */
	function block(event: Event) {
		if (!current) return;
		event.preventDefault();
		event.stopPropagation();
		event.stopImmediatePropagation();
	}

	function apply() {
		if (current) {
			node.setAttribute("aria-disabled", "true");
			node.dataset.locked = "true";
			node.style.opacity = "0.4";
			node.style.cursor = "not-allowed";
		} else {
			node.removeAttribute("aria-disabled");
			delete node.dataset.locked;
			node.style.opacity = "";
			node.style.cursor = "";
			hide();
		}
	}

	apply();
	node.addEventListener("click", block, true);
	node.addEventListener("mouseenter", show);
	node.addEventListener("mousemove", move);
	node.addEventListener("mouseleave", hide);

	return {
		update(next: string | null | undefined) {
			current = next;
			hide();
			apply();
		},
		destroy() {
			hide();
			node.removeEventListener("click", block, true);
			node.removeEventListener("mouseenter", show);
			node.removeEventListener("mousemove", move);
			node.removeEventListener("mouseleave", hide);
		},
	};
}
