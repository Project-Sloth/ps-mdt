import { TSESTree } from '@typescript-eslint/types';

type Handler<T> = (node: T, state: State) => undefined;

export type Handlers = {
	[T in TSESTree.Node['type']]: Handler<Extract<TSESTree.Node, { type: T }>>;
};

export type TypeAnnotationNodes =
	| TSESTree.TypeNode
	| TSESTree.TypeElement
	| TSESTree.TSTypeAnnotation
	| TSESTree.TSPropertySignature
	| TSESTree.TSTypeParameter
	| TSESTree.TSTypeParameterDeclaration
	| TSESTree.TSTypeParameterInstantiation
	| TSESTree.TSEnumMember
	| TSESTree.TSInterfaceHeritage
	| TSESTree.TSClassImplements
	| TSExpressionWithTypeArguments;

type TSExpressionWithTypeArguments = {
	type: 'TSExpressionWithTypeArguments';
	expression: any;
};

// `@typescript-eslint/types` differs from the official `estree` spec by handling
// comments differently. This is a node which we can use to ensure type saftey.
export type NodeWithComments = {
	leadingComments?: TSESTree.Comment[] | undefined;
	trailingComments?: TSESTree.Comment[] | undefined;
} & TSESTree.Node;

export interface State {
	commands: Command[];
	comments: TSESTree.Comment[];
	multiline: boolean;
	quote: "'" | '"';
}

export interface Location {
	type: 'Location';
	line: number;
	column: number;
}

export interface Newline {
	type: 'Newline';
}

export interface Indent {
	type: 'Indent';
}

export interface Dedent {
	type: 'Dedent';
}

export interface IndentChange {
	type: 'IndentChange';
	offset: number;
}

export interface CommentChunk {
	type: 'Comment';
	comment: TSESTree.Comment;
}

export type Command = string | Location | Newline | Indent | Dedent | CommentChunk | Command[];

export interface PrintOptions {
	sourceMapSource?: string;
	sourceMapContent?: string;
	sourceMapEncodeMappings?: boolean; // default true
	indent?: string; // default tab
	quotes?: 'single' | 'double'; // default single
}
