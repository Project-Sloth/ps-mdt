import { AnyExtension, MaybeThisParameterType, RemoveThis } from '../types.js';
/**
 * Returns a field from an extension
 * @param extension The Tiptap extension
 * @param field The field, for example `renderHTML` or `priority`
 * @param context The context object that should be passed as `this` into the function
 * @returns The field value
 */
export declare function getExtensionField<T = any>(extension: AnyExtension, field: string, context?: Omit<MaybeThisParameterType<T>, 'parent'>): RemoveThis<T>;
//# sourceMappingURL=getExtensionField.d.ts.map