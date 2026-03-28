import { Node } from '@tiptap/core';
export interface HorizontalRuleOptions {
    /**
     * The HTML attributes for a horizontal rule node.
     * @default {}
     * @example { class: 'foo' }
     */
    HTMLAttributes: Record<string, any>;
}
declare module '@tiptap/core' {
    interface Commands<ReturnType> {
        horizontalRule: {
            /**
             * Add a horizontal rule
             * @example editor.commands.setHorizontalRule()
             */
            setHorizontalRule: () => ReturnType;
        };
    }
}
/**
 * This extension allows you to insert horizontal rules.
 * @see https://www.tiptap.dev/api/nodes/horizontal-rule
 */
export declare const HorizontalRule: Node<HorizontalRuleOptions, any>;
//# sourceMappingURL=horizontal-rule.d.ts.map