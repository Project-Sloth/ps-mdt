/** Gets the parent resource name with safe fallback */
export function GetParentResourceName(): string {
	return (window as any).GetParentResourceName?.() || "ps-mdt";
}
