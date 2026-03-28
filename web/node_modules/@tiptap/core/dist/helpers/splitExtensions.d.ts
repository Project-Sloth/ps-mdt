import { Extension } from '../Extension.js';
import { Mark } from '../Mark.js';
import { Node } from '../Node.js';
import { Extensions } from '../types.js';
export declare function splitExtensions(extensions: Extensions): {
    baseExtensions: Extension<any, any>[];
    nodeExtensions: Node<any, any>[];
    markExtensions: Mark<any, any>[];
};
//# sourceMappingURL=splitExtensions.d.ts.map