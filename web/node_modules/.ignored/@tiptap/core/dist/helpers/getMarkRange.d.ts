import { MarkType, ResolvedPos } from '@tiptap/pm/model';
import { Range } from '../types.js';
/**
 * Get the range of a mark at a resolved position.
 */
export declare function getMarkRange(
/**
 * The position to get the mark range for.
 */
$pos: ResolvedPos, 
/**
 * The mark type to get the range for.
 */
type: MarkType, 
/**
 * The attributes to match against.
 * If not provided, only the first mark at the position will be matched.
 */
attributes?: Record<string, any>): Range | void;
//# sourceMappingURL=getMarkRange.d.ts.map