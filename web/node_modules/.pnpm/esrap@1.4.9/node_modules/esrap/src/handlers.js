/** @import { TSESTree } from '@typescript-eslint/types' */
/** @import { Command, Dedent, Handlers, Location, Indent, Newline, NodeWithComments, State, TypeAnnotationNodes } from './types' */

/** @type {Newline} */
const newline = { type: 'Newline' };

/** @type {Indent} */
const indent = { type: 'Indent' };

/** @type {Dedent} */
const dedent = { type: 'Dedent' };

/**
 * @returns {Command[]}
 */
function create_sequence() {
	return [];
}

/**
 * Rough estimate of the combined width of a group of commands
 * @param {Command[]} commands
 * @param {number} from
 * @param {number} to
 */
function measure(commands, from, to = commands.length) {
	let total = 0;
	for (let i = from; i < to; i += 1) {
		const command = commands[i];
		if (typeof command === 'string') {
			total += command.length;
		} else if (Array.isArray(command)) {
			total +=
				command.length === 0
					? 2 // assume this is ', '
					: measure(command, 0);
		}
	}

	return total;
}

/**
 * @param {TSESTree.Node} node
 * @param {State} state
 */
export function handle(node, state) {
	const node_with_comments = /** @type {NodeWithComments} */ (node);

	const handler = handlers[node.type];

	if (!handler) {
		throw new Error(`Not implemented ${node.type}`);
	}

	if (node_with_comments.leadingComments) {
		prepend_comments(node_with_comments.leadingComments, state, false);
	}

	// @ts-expect-error
	handler(node, state);

	if (node_with_comments.trailingComments) {
		state.comments.push(node_with_comments.trailingComments[0]); // there is only ever one
	}
}

/**
 * @param {number} line
 * @param {number} column
 * @returns {Location}
 */
function l(line, column) {
	return {
		type: 'Location',
		line,
		column
	};
}

/**
 * @param {string} content
 * @param {TSESTree.Node} node
 * @returns {string | Command[]}
 */
function c(content, node) {
	return node.loc
		? [
				l(node.loc.start.line, node.loc.start.column),
				content,
				l(node.loc.end.line, node.loc.end.column)
			]
		: content;
}

/**
 * @param {TSESTree.Comment[]} comments
 * @param {State} state
 * @param {boolean} newlines
 */
function prepend_comments(comments, state, newlines) {
	for (const comment of comments) {
		state.commands.push({ type: 'Comment', comment });

		if (newlines || comment.type === 'Line' || /\n/.test(comment.value)) {
			state.commands.push(newline);
		} else {
			state.commands.push(' ');
		}
	}
}

/**
 * @param {string} string
 * @param {'\'' | '"'} char
 */
function quote(string, char) {
	let out = char;

	for (const c of string) {
		if (c === '\\') {
			out += '\\\\';
		} else if (c === char) {
			out += '\\' + c;
		} else if (c === '\n') {
			out += '\\n';
		} else if (c === '\r') {
			out += '\\r';
		} else {
			out += c;
		}
	}

	return out + char;
}

const OPERATOR_PRECEDENCE = {
	'||': 2,
	'&&': 3,
	'??': 4,
	'|': 5,
	'^': 6,
	'&': 7,
	'==': 8,
	'!=': 8,
	'===': 8,
	'!==': 8,
	'<': 9,
	'>': 9,
	'<=': 9,
	'>=': 9,
	in: 9,
	instanceof: 9,
	'<<': 10,
	'>>': 10,
	'>>>': 10,
	'+': 11,
	'-': 11,
	'*': 12,
	'%': 12,
	'/': 12,
	'**': 13
};

/** @type {Record<TSESTree.Expression['type'] | 'Super' | 'RestElement', number>} */
const EXPRESSIONS_PRECEDENCE = {
	JSXFragment: 20,
	JSXElement: 20,
	ArrayPattern: 20,
	ObjectPattern: 20,
	ArrayExpression: 20,
	TaggedTemplateExpression: 20,
	ThisExpression: 20,
	Identifier: 20,
	TemplateLiteral: 20,
	Super: 20,
	SequenceExpression: 20,
	MemberExpression: 19,
	MetaProperty: 19,
	CallExpression: 19,
	ChainExpression: 19,
	ImportExpression: 19,
	NewExpression: 19,
	Literal: 18,
	TSSatisfiesExpression: 18,
	TSInstantiationExpression: 18,
	TSNonNullExpression: 18,
	TSTypeAssertion: 18,
	AwaitExpression: 17,
	ClassExpression: 17,
	FunctionExpression: 17,
	ObjectExpression: 17,
	TSAsExpression: 16,
	UpdateExpression: 16,
	UnaryExpression: 15,
	BinaryExpression: 14,
	LogicalExpression: 13,
	ConditionalExpression: 4,
	ArrowFunctionExpression: 3,
	AssignmentExpression: 3,
	YieldExpression: 2,
	RestElement: 1
};

/**
 *
 * @param {TSESTree.Expression | TSESTree.PrivateIdentifier} node
 * @param {TSESTree.BinaryExpression | TSESTree.LogicalExpression} parent
 * @param {boolean} is_right
 * @returns
 */
function needs_parens(node, parent, is_right) {
	if (node.type === 'PrivateIdentifier') return false;

	// special case where logical expressions and coalesce expressions cannot be mixed,
	// either of them need to be wrapped with parentheses
	if (
		node.type === 'LogicalExpression' &&
		parent.type === 'LogicalExpression' &&
		((parent.operator === '??' && node.operator !== '??') ||
			(parent.operator !== '??' && node.operator === '??'))
	) {
		return true;
	}

	const precedence = EXPRESSIONS_PRECEDENCE[node.type];
	const parent_precedence = EXPRESSIONS_PRECEDENCE[parent.type];

	if (precedence !== parent_precedence) {
		// Different node types
		return (
			(!is_right && precedence === 15 && parent_precedence === 14 && parent.operator === '**') ||
			precedence < parent_precedence
		);
	}

	if (precedence !== 13 && precedence !== 14) {
		// Not a `LogicalExpression` or `BinaryExpression`
		return false;
	}

	if (
		/** @type {TSESTree.BinaryExpression} */ (node).operator === '**' &&
		parent.operator === '**'
	) {
		// Exponentiation operator has right-to-left associativity
		return !is_right;
	}

	if (is_right) {
		// Parenthesis are used if both operators have the same precedence
		return (
			OPERATOR_PRECEDENCE[/** @type {TSESTree.BinaryExpression} */ (node).operator] <=
			OPERATOR_PRECEDENCE[parent.operator]
		);
	}

	return (
		OPERATOR_PRECEDENCE[/** @type {TSESTree.BinaryExpression} */ (node).operator] <
		OPERATOR_PRECEDENCE[parent.operator]
	);
}

/** @param {TSESTree.Node} node */
function has_call_expression(node) {
	while (node) {
		if (node.type === 'CallExpression') {
			return true;
		} else if (node.type === 'MemberExpression') {
			node = node.object;
		} else {
			return false;
		}
	}
}

const grouped_expression_types = [
	'ImportDeclaration',
	'VariableDeclaration',
	'ExportDefaultDeclaration',
	'ExportNamedDeclaration'
];

/**
 * @param {TSESTree.Node[]} nodes
 * @param {State} state
 */
const handle_body = (nodes, state) => {
	let last_statement = /** @type {TSESTree.Node} */ ({
		type: 'EmptyStatement'
	});
	let first = true;
	let needs_margin = false;

	for (const statement of nodes) {
		if (statement.type === 'EmptyStatement') continue;

		const margin = create_sequence();

		if (!first) state.commands.push(margin, newline);
		first = false;

		const statement_with_comments = /** @type {NodeWithComments} */ (statement);
		const leading_comments = statement_with_comments.leadingComments;
		delete statement_with_comments.leadingComments;

		if (leading_comments && leading_comments.length > 0) {
			prepend_comments(leading_comments, state, true);
		}

		const child_state = { ...state, multiline: false };
		handle(statement, child_state);

		if (
			child_state.multiline ||
			needs_margin ||
			((grouped_expression_types.includes(statement.type) ||
				grouped_expression_types.includes(last_statement.type)) &&
				last_statement.type !== statement.type)
		) {
			margin.push('\n');
		}

		let add_newline = false;

		while (state.comments.length) {
			const comment = /** @type {TSESTree.Comment} */ (state.comments.shift());

			state.commands.push(add_newline ? newline : ' ', { type: 'Comment', comment });
			add_newline = comment.type === 'Line';
		}

		needs_margin = child_state.multiline;
		last_statement = statement;
	}
};

/**
 * @param {TSESTree.VariableDeclaration} node
 * @param {State} state
 */
const handle_var_declaration = (node, state) => {
	const index = state.commands.length;

	const open = create_sequence();
	const join = create_sequence();
	const child_state = { ...state, multiline: false };

	state.commands.push(`${node.kind} `, open);

	let first = true;

	for (const d of node.declarations) {
		if (!first) state.commands.push(join);
		first = false;

		handle(d, child_state);
	}

	const multiline =
		child_state.multiline || (node.declarations.length > 1 && measure(state.commands, index) > 50);

	if (multiline) {
		state.multiline = true;
		if (node.declarations.length > 1) open.push(indent);
		join.push(',', newline);
		if (node.declarations.length > 1) state.commands.push(dedent);
	} else {
		join.push(', ');
	}
};

/**
 * @template {TSESTree.Node} T
 * @param {Array<T | null>} nodes
 * @param {State} state
 * @param {boolean} spaces
 * @param {(node: T, state: State) => void} fn
 */
function sequence(nodes, state, spaces, fn, separator = ',') {
	if (nodes.length === 0) return;

	const index = state.commands.length;

	const open = create_sequence();
	const join = create_sequence();
	const close = create_sequence();

	state.commands.push(open);

	const child_state = { ...state, multiline: false };

	let prev;

	for (let i = 0; i < nodes.length; i += 1) {
		const node = nodes[i];
		const is_first = i === 0;
		const is_last = i === nodes.length - 1;

		if (node) {
			if (!is_first && !prev) {
				state.commands.push(join);
			}

			fn(node, child_state);

			if (!is_last) {
				state.commands.push(separator);
			}

			if (state.comments.length > 0) {
				state.commands.push(' ');

				while (state.comments.length) {
					const comment = /** @type {TSESTree.Comment} */ (state.comments.shift());
					state.commands.push({ type: 'Comment', comment });
					if (!is_last) state.commands.push(join);
				}

				child_state.multiline = true;
			} else {
				if (!is_last) state.commands.push(join);
			}
		} else {
			// This is only used for ArrayPattern and ArrayExpression, but
			// it makes more sense to have the logic here than there, because
			// otherwise we'd duplicate a lot more stuff
			state.commands.push(separator);
		}

		prev = node;
	}

	state.commands.push(close);

	const multiline = child_state.multiline || measure(state.commands, index) > 50;

	if (multiline) {
		state.multiline = true;

		open.push(indent, newline);
		join.push(newline);
		close.push(dedent, newline);
	} else {
		if (spaces) open.push(' ');
		join.push(' ');
		if (spaces) close.push(' ');
	}
}

/**
 * @param {TypeAnnotationNodes} node
 * @param {State} state
 */
function handle_type_annotation(node, state) {
	switch (node.type) {
		case 'TSNumberKeyword':
			state.commands.push('number');
			break;
		case 'TSStringKeyword':
			state.commands.push('string');
			break;
		case 'TSBooleanKeyword':
			state.commands.push('boolean');
			break;
		case 'TSAnyKeyword':
			state.commands.push('any');
			break;
		case 'TSVoidKeyword':
			state.commands.push('void');
			break;
		case 'TSUnknownKeyword':
			state.commands.push('unknown');
			break;
		case 'TSNeverKeyword':
			state.commands.push('never');
			break;
		case 'TSSymbolKeyword':
			state.commands.push('symbol');
			break;
		case 'TSNullKeyword':
			state.commands.push('null');
			break;
		case 'TSUndefinedKeyword':
			state.commands.push('undefined');
			break;
		case 'TSArrayType':
			handle_type_annotation(node.elementType, state);
			state.commands.push('[]');
			break;
		case 'TSTypeAnnotation':
			state.commands.push(': ');
			handle_type_annotation(node.typeAnnotation, state);
			break;
		case 'TSTypeLiteral':
			state.commands.push('{ ');
			sequence(node.members, state, false, handle_type_annotation, ';');
			state.commands.push(' }');
			break;
		case 'TSPropertySignature':
			handle(node.key, state);
			if (node.optional) state.commands.push('?');
			if (node.typeAnnotation) handle_type_annotation(node.typeAnnotation, state);
			break;
		case 'TSTypeReference':
			handle(node.typeName, state);

			if (node.typeArguments) {
				handle_type_annotation(node.typeArguments, state);
			}
			break;
		case 'TSTypeParameterInstantiation':
		case 'TSTypeParameterDeclaration':
			state.commands.push('<');
			for (let i = 0; i < node.params.length; i++) {
				handle_type_annotation(node.params[i], state);
				if (i != node.params.length - 1) state.commands.push(', ');
			}
			state.commands.push('>');
			break;
		case 'TSTypeParameter':
			// @ts-expect-error `acorn-typescript` and `@typescript-eslint/types` have slightly different type definitions
			state.commands.push(node.name);

			if (node.constraint) {
				state.commands.push(' extends ');
				handle_type_annotation(node.constraint, state);
			}
			break;
		case 'TSTypeQuery':
			state.commands.push('typeof ');
			handle(node.exprName, state);
			break;
		case 'TSEnumMember':
			handle(node.id, state);
			if (node.initializer) {
				state.commands.push(' = ');
				handle(node.initializer, state);
			}
			break;
		case 'TSFunctionType':
			if (node.typeParameters) handle_type_annotation(node.typeParameters, state);

			// @ts-expect-error `acorn-typescript` and `@typescript-eslint/types` have slightly different type definitions
			const parameters = node.parameters;
			state.commands.push('(');
			sequence(parameters, state, false, handle);

			state.commands.push(') => ');

			// @ts-expect-error `acorn-typescript` and `@typescript-eslint/types` have slightly different type definitions
			handle_type_annotation(node.typeAnnotation.typeAnnotation, state);
			break;
		case 'TSIndexSignature':
			const indexParameters = node.parameters;
			state.commands.push('[');
			sequence(indexParameters, state, false, handle);
			state.commands.push(']');

			// @ts-expect-error `acorn-typescript` and `@typescript-eslint/types` have slightly different type definitions
			handle_type_annotation(node.typeAnnotation, state);
			break;
		case 'TSMethodSignature':
			handle(node.key, state);

			// @ts-expect-error `acorn-typescript` and `@typescript-eslint/types` have slightly different type definitions
			const parametersSignature = node.parameters;
			state.commands.push('(');
			sequence(parametersSignature, state, false, handle);
			state.commands.push(')');

			// @ts-expect-error `acorn-typescript` and `@typescript-eslint/types` have slightly different type definitions
			handle_type_annotation(node.typeAnnotation, state);
			break;
		case 'TSExpressionWithTypeArguments':
			handle(node.expression, state);
			break;
		case 'TSTupleType':
			state.commands.push('[');
			sequence(node.elementTypes, state, false, handle_type_annotation);
			state.commands.push(']');
			break;
		case 'TSNamedTupleMember':
			handle(node.label, state);
			state.commands.push(': ');
			handle_type_annotation(node.elementType, state);

			break;
		case 'TSUnionType':
			sequence(node.types, state, false, handle_type_annotation, ' |');
			break;
		case 'TSIntersectionType':
			sequence(node.types, state, false, handle_type_annotation, ' &');
			break;
		case 'TSLiteralType':
			handle(node.literal, state);
			break;
		case 'TSConditionalType':
			handle_type_annotation(node.checkType, state);
			state.commands.push(' extends ');
			handle_type_annotation(node.extendsType, state);
			state.commands.push(' ? ');
			handle_type_annotation(node.trueType, state);
			state.commands.push(' : ');
			handle_type_annotation(node.falseType, state);
			break;
		case 'TSIndexedAccessType':
			handle_type_annotation(node.objectType, state);
			state.commands.push('[');
			handle_type_annotation(node.indexType, state);
			state.commands.push(']');
			break;
		case 'TSImportType':
			state.commands.push('import(');
			handle(node.argument, state);
			state.commands.push(')');

			if (node.qualifier) {
				state.commands.push('.');
				handle(node.qualifier, state);
			}
			break;
		default:
			throw new Error(`Not implemented type annotation ${node.type}`);
	}
}

/** @satisfies {Record<string, (node: any, state: State) => undefined>} */
const shared = {
	/**
	 * @param {TSESTree.ArrayExpression | TSESTree.ArrayPattern} node
	 * @param {State} state
	 */
	'ArrayExpression|ArrayPattern': (node, state) => {
		state.commands.push('[');
		sequence(/** @type {TSESTree.Node[]} */ (node.elements), state, false, handle);
		state.commands.push(']');
	},

	/**
	 * @param {TSESTree.BinaryExpression | TSESTree.LogicalExpression} node
	 * @param {State} state
	 */
	'BinaryExpression|LogicalExpression': (node, state) => {
		// TODO
		// const is_in = node.operator === 'in';
		// if (is_in) {
		// 	// Avoids confusion in `for` loops initializers
		// 	chunks.push(c('('));
		// }

		if (needs_parens(node.left, node, false)) {
			state.commands.push('(');
			handle(node.left, state);
			state.commands.push(')');
		} else {
			handle(node.left, state);
		}

		state.commands.push(` ${node.operator} `);

		if (needs_parens(node.right, node, true)) {
			state.commands.push('(');
			handle(node.right, state);
			state.commands.push(')');
		} else {
			handle(node.right, state);
		}
	},

	/**
	 * @param {TSESTree.BlockStatement | TSESTree.ClassBody} node
	 * @param {State} state
	 */
	'BlockStatement|ClassBody': (node, state) => {
		if (node.loc) {
			const { line, column } = node.loc.start;
			state.commands.push(l(line, column), '{', l(line, column + 1));
		} else {
			state.commands.push('{');
		}

		if (node.body.length > 0) {
			state.multiline = true;
			state.commands.push(indent, newline);
			handle_body(node.body, state);
			state.commands.push(dedent, newline);
		}

		if (node.loc) {
			const { line, column } = node.loc.end;
			state.commands.push(l(line, column - 1), '}', l(line, column));
		} else {
			state.commands.push('}');
		}
	},

	/**
	 * @param {TSESTree.CallExpression | TSESTree.NewExpression} node
	 * @param {State} state
	 */
	'CallExpression|NewExpression': (node, state) => {
		if (node.type === 'NewExpression') {
			state.commands.push('new ');
		}

		const needs_parens =
			EXPRESSIONS_PRECEDENCE[node.callee.type] < EXPRESSIONS_PRECEDENCE.CallExpression ||
			(node.type === 'NewExpression' && has_call_expression(node.callee));

		if (needs_parens) {
			state.commands.push('(');
			handle(node.callee, state);
			state.commands.push(')');
		} else {
			handle(node.callee, state);
		}

		if (/** @type {TSESTree.CallExpression} */ (node).optional) {
			state.commands.push('?.');
		}

		if (node.typeArguments) handle_type_annotation(node.typeArguments, state);

		const open = create_sequence();
		const join = create_sequence();
		const close = create_sequence();

		state.commands.push('(', open);

		// if the final argument is multiline, it doesn't need to force all the
		// other arguments to also be multiline
		const child_state = { ...state, multiline: false };
		const final_state = { ...state, multiline: false };

		for (let i = 0; i < node.arguments.length; i += 1) {
			if (i > 0) {
				if (state.comments.length > 0) {
					state.commands.push(', ');

					while (state.comments.length) {
						const comment = /** @type {TSESTree.Comment} */ (state.comments.shift());

						state.commands.push({ type: 'Comment', comment });

						if (comment.type === 'Line') {
							child_state.multiline = true;
							state.commands.push(newline);
						} else {
							state.commands.push(' ');
						}
					}
				} else {
					state.commands.push(join);
				}
			}

			const p = node.arguments[i];

			handle(p, i === node.arguments.length - 1 ? final_state : child_state);
		}

		state.commands.push(close, ')');

		const multiline = child_state.multiline;

		if (multiline || final_state.multiline) {
			state.multiline = true;
		}

		if (multiline) {
			open.push(indent, newline);
			join.push(',', newline);
			close.push(dedent, newline);
		} else {
			join.push(', ');
		}
	},

	/**
	 * @param {TSESTree.ClassDeclaration | TSESTree.ClassExpression} node
	 * @param {State} state
	 */
	'ClassDeclaration|ClassExpression': (node, state) => {
		state.commands.push('class ');

		if (node.id) {
			handle(node.id, state);
			state.commands.push(' ');
		}

		if (node.superClass) {
			state.commands.push('extends ');
			handle(node.superClass, state);
			state.commands.push(' ');
		}

		if (node.implements) {
			state.commands.push('implements ');
			sequence(node.implements, state, false, handle_type_annotation);
		}

		handle(node.body, state);
	},

	/**
	 * @param {TSESTree.ForInStatement | TSESTree.ForOfStatement} node
	 * @param {State} state
	 */
	'ForInStatement|ForOfStatement': (node, state) => {
		state.commands.push('for ');
		if (node.type === 'ForOfStatement' && node.await) state.commands.push('await ');
		state.commands.push('(');

		if (node.left.type === 'VariableDeclaration') {
			handle_var_declaration(node.left, state);
		} else {
			handle(node.left, state);
		}

		state.commands.push(node.type === 'ForInStatement' ? ` in ` : ` of `);
		handle(node.right, state);
		state.commands.push(') ');
		handle(node.body, state);
	},

	/**
	 * @param {TSESTree.FunctionDeclaration | TSESTree.FunctionExpression} node
	 * @param {State} state
	 */
	'FunctionDeclaration|FunctionExpression': (node, state) => {
		if (node.async) state.commands.push('async ');
		state.commands.push(node.generator ? 'function* ' : 'function ');
		if (node.id) handle(node.id, state);

		if (node.typeParameters) {
			handle_type_annotation(node.typeParameters, state);
		}

		state.commands.push('(');
		sequence(node.params, state, false, handle);
		state.commands.push(')');

		if (node.returnType) handle_type_annotation(node.returnType, state);

		state.commands.push(' ');

		handle(node.body, state);
	},

	/**
	 * @param {TSESTree.RestElement | TSESTree.SpreadElement} node
	 * @param {State} state
	 */
	'RestElement|SpreadElement': (node, state) => {
		state.commands.push('...');
		handle(node.argument, state);

		// @ts-expect-error `acorn-typescript` and `@typescript-eslint/types` have slightly different type definitions
		if (node.typeAnnotation) handle_type_annotation(node.typeAnnotation, state);
	}
};

/** @type {Handlers} */
const handlers = {
	ArrayExpression: shared['ArrayExpression|ArrayPattern'],

	ArrayPattern: shared['ArrayExpression|ArrayPattern'],

	ArrowFunctionExpression: (node, state) => {
		if (node.async) state.commands.push('async ');

		state.commands.push('(');
		sequence(node.params, state, false, handle);
		state.commands.push(') => ');

		if (
			node.body.type === 'ObjectExpression' ||
			(node.body.type === 'AssignmentExpression' && node.body.left.type === 'ObjectPattern') ||
			(node.body.type === 'LogicalExpression' && node.body.left.type === 'ObjectExpression') ||
			(node.body.type === 'ConditionalExpression' && node.body.test.type === 'ObjectExpression')
		) {
			state.commands.push('(');
			handle(node.body, state);
			state.commands.push(')');
		} else {
			handle(node.body, state);
		}
	},

	AssignmentExpression(node, state) {
		handle(node.left, state);
		state.commands.push(` ${node.operator} `);
		handle(node.right, state);
	},

	AssignmentPattern(node, state) {
		handle(node.left, state);
		state.commands.push(' = ');
		handle(node.right, state);
	},

	AwaitExpression(node, state) {
		if (node.argument) {
			const precedence = EXPRESSIONS_PRECEDENCE[node.argument.type];

			if (precedence && precedence < EXPRESSIONS_PRECEDENCE.AwaitExpression) {
				state.commands.push('await (');
				handle(node.argument, state);
				state.commands.push(')');
			} else {
				state.commands.push('await ');
				handle(node.argument, state);
			}
		} else {
			state.commands.push('await');
		}
	},

	BinaryExpression: shared['BinaryExpression|LogicalExpression'],

	BlockStatement: shared['BlockStatement|ClassBody'],

	BreakStatement(node, state) {
		if (node.label) {
			state.commands.push('break ');
			handle(node.label, state);
			state.commands.push(';');
		} else {
			state.commands.push('break;');
		}
	},

	CallExpression: shared['CallExpression|NewExpression'],

	ChainExpression(node, state) {
		handle(node.expression, state);
	},

	ClassBody: shared['BlockStatement|ClassBody'],

	ClassDeclaration: shared['ClassDeclaration|ClassExpression'],

	ClassExpression: shared['ClassDeclaration|ClassExpression'],

	ConditionalExpression(node, state) {
		if (EXPRESSIONS_PRECEDENCE[node.test.type] > EXPRESSIONS_PRECEDENCE.ConditionalExpression) {
			handle(node.test, state);
		} else {
			state.commands.push('(');
			handle(node.test, state);
			state.commands.push(')');
		}

		const if_true = create_sequence();
		const if_false = create_sequence();

		const child_state = { ...state, multiline: false };

		state.commands.push(if_true);
		handle(node.consequent, child_state);
		state.commands.push(if_false);
		handle(node.alternate, child_state);

		const multiline = child_state.multiline;

		if (multiline) {
			if_true.push(indent, newline, '? ');
			if_false.push(newline, ': ');
			state.commands.push(dedent);
		} else {
			if_true.push(' ? ');
			if_false.push(' : ');
		}
	},

	ContinueStatement(node, state) {
		if (node.label) {
			state.commands.push('continue ');
			handle(node.label, state);
			state.commands.push(';');
		} else {
			state.commands.push('continue;');
		}
	},

	DebuggerStatement(node, state) {
		state.commands.push(c('debugger', node), ';');
	},

	Decorator(node, state) {
		state.commands.push('@');
		handle(node.expression, state);
		state.commands.push(newline);
	},

	DoWhileStatement(node, state) {
		state.commands.push('do ');
		handle(node.body, state);
		state.commands.push(' while (');
		handle(node.test, state);
		state.commands.push(');');
	},

	EmptyStatement(node, state) {
		state.commands.push(';');
	},

	ExportAllDeclaration(node, state) {
		state.commands.push('export * ');
		if (node.exported) {
			state.commands.push('as ');
			handle(node.exported, state);
		}
		state.commands.push(' from ');
		handle(node.source, state);
		state.commands.push(';');
	},

	ExportDefaultDeclaration(node, state) {
		state.commands.push('export default ');

		handle(node.declaration, state);

		if (node.declaration.type !== 'FunctionDeclaration') {
			state.commands.push(';');
		}
	},

	ExportNamedDeclaration(node, state) {
		state.commands.push('export ');

		if (node.declaration) {
			handle(node.declaration, state);
			return;
		}

		state.commands.push('{');
		sequence(node.specifiers, state, true, (s, state) => {
			handle(s.local, state);

			if (s.local.name !== s.exported.name) {
				state.commands.push(' as ');
				handle(s.exported, state);
			}
		});
		state.commands.push('}');

		if (node.source) {
			state.commands.push(' from ');
			handle(node.source, state);
		}

		state.commands.push(';');
	},

	ExpressionStatement(node, state) {
		if (
			node.expression.type === 'ObjectExpression' ||
			(node.expression.type === 'AssignmentExpression' &&
				node.expression.left.type === 'ObjectPattern') ||
			node.expression.type === 'FunctionExpression'
		) {
			// is an AssignmentExpression to an ObjectPattern
			state.commands.push('(');
			handle(node.expression, state);
			state.commands.push(');');
			return;
		}

		handle(node.expression, state);
		state.commands.push(';');
	},

	ForStatement: (node, state) => {
		state.commands.push('for (');

		if (node.init) {
			if (node.init.type === 'VariableDeclaration') {
				handle_var_declaration(node.init, state);
			} else {
				handle(node.init, state);
			}
		}

		state.commands.push('; ');
		if (node.test) handle(node.test, state);
		state.commands.push('; ');
		if (node.update) handle(node.update, state);

		state.commands.push(') ');
		handle(node.body, state);
	},

	ForInStatement: shared['ForInStatement|ForOfStatement'],

	ForOfStatement: shared['ForInStatement|ForOfStatement'],

	FunctionDeclaration: shared['FunctionDeclaration|FunctionExpression'],

	FunctionExpression: shared['FunctionDeclaration|FunctionExpression'],

	Identifier(node, state) {
		let name = node.name;
		state.commands.push(c(name, node));

		if (node.typeAnnotation) handle_type_annotation(node.typeAnnotation, state);
	},

	IfStatement(node, state) {
		state.commands.push('if (');
		handle(node.test, state);
		state.commands.push(') ');
		handle(node.consequent, state);

		if (node.alternate) {
			state.commands.push(' else ');
			handle(node.alternate, state);
		}
	},

	ImportDeclaration(node, state) {
		if (node.specifiers.length === 0) {
			state.commands.push('import ');
			handle(node.source, state);
			state.commands.push(';');
			return;
		}

		/** @type {TSESTree.ImportNamespaceSpecifier | null} */
		let namespace_specifier = null;

		/** @type {TSESTree.ImportDefaultSpecifier | null} */
		let default_specifier = null;

		/** @type {TSESTree.ImportSpecifier[]} */
		const named_specifiers = [];

		for (const s of node.specifiers) {
			if (s.type === 'ImportNamespaceSpecifier') {
				namespace_specifier = s;
			} else if (s.type === 'ImportDefaultSpecifier') {
				default_specifier = s;
			} else {
				named_specifiers.push(s);
			}
		}

		state.commands.push('import ');
		if (node.importKind == 'type') state.commands.push('type ');

		if (default_specifier) {
			state.commands.push(c(default_specifier.local.name, default_specifier));
			if (namespace_specifier || named_specifiers.length > 0) state.commands.push(', ');
		}

		if (namespace_specifier) {
			state.commands.push(c('* as ' + namespace_specifier.local.name, namespace_specifier));
		}

		if (named_specifiers.length > 0) {
			state.commands.push('{');
			sequence(named_specifiers, state, true, (s, state) => {
				if (s.local.name !== s.imported.name) {
					handle(s.imported, state);
					state.commands.push(' as ');
				}

				if (s.importKind == 'type') state.commands.push('type ');
				handle(s.local, state);
			});
			state.commands.push('}');
		}

		state.commands.push(' from ');
		handle(node.source, state);
		if (node.attributes && node.attributes.length > 0) {
			state.commands.push(' with { ');
			for (let index = 0; index < node.attributes.length; index++) {
				const { key, value } = node.attributes[index];
				handle(key, state);
				state.commands.push(': ');
				handle(value, state);
				if (index + 1 !== node.attributes.length) {
					state.commands.push(', ');
				}
			}
			state.commands.push(' }');
		}
		state.commands.push(';');
	},

	ImportExpression(node, state) {
		state.commands.push('import(');
		handle(node.source, state);
		//@ts-expect-error for some reason the types haven't been updated
		if (node.arguments) {
			//@ts-expect-error
			for (let index = 0; index < node.arguments.length; index++) {
				state.commands.push(', ');
				//@ts-expect-error
				handle(node.arguments[index], state);
			}
		}
		state.commands.push(')');
	},

	LabeledStatement(node, state) {
		handle(node.label, state);
		state.commands.push(': ');
		handle(node.body, state);
	},

	Literal(node, state) {
		// TODO do we need to handle weird unicode characters somehow?
		// str.replace(/\\u(\d{4})/g, (m, n) => String.fromCharCode(+n))

		const value =
			node.raw ||
			(typeof node.value === 'string' ? quote(node.value, state.quote) : String(node.value));

		state.commands.push(c(value, node));
	},

	LogicalExpression: shared['BinaryExpression|LogicalExpression'],

	MemberExpression(node, state) {
		if (EXPRESSIONS_PRECEDENCE[node.object.type] < EXPRESSIONS_PRECEDENCE.MemberExpression) {
			state.commands.push('(');
			handle(node.object, state);
			state.commands.push(')');
		} else {
			handle(node.object, state);
		}

		if (node.computed) {
			if (node.optional) {
				state.commands.push('?.');
			}
			state.commands.push('[');
			handle(node.property, state);
			state.commands.push(']');
		} else {
			state.commands.push(node.optional ? '?.' : '.');
			handle(node.property, state);
		}
	},

	MetaProperty(node, state) {
		handle(node.meta, state);
		state.commands.push('.');
		handle(node.property, state);
	},

	MethodDefinition(node, state) {
		if (node.decorators) {
			for (const decorator of node.decorators) {
				handle(decorator, state);
			}
		}

		if (node.static) {
			state.commands.push('static ');
		}

		if (node.kind === 'get' || node.kind === 'set') {
			// Getter or setter
			state.commands.push(node.kind + ' ');
		}

		if (node.value.async) {
			state.commands.push('async ');
		}

		if (node.value.generator) {
			state.commands.push('*');
		}

		if (node.computed) state.commands.push('[');
		handle(node.key, state);
		if (node.computed) state.commands.push(']');

		state.commands.push('(');
		sequence(node.value.params, state, false, handle);
		state.commands.push(')');

		if (node.value.returnType) handle_type_annotation(node.value.returnType, state);

		state.commands.push(' ');

		if (node.value.body) handle(node.value.body, state);
	},

	NewExpression: shared['CallExpression|NewExpression'],

	ObjectExpression(node, state) {
		state.commands.push('{');
		sequence(node.properties, state, true, (p, state) => {
			if (p.type === 'Property' && p.value.type === 'FunctionExpression') {
				const fn = /** @type {TSESTree.FunctionExpression} */ (p.value);

				if (p.kind === 'get' || p.kind === 'set') {
					state.commands.push(p.kind + ' ');
				} else {
					if (fn.async) state.commands.push('async ');
					if (fn.generator) state.commands.push('*');
				}

				if (p.computed) state.commands.push('[');
				handle(p.key, state);
				if (p.computed) state.commands.push(']');

				state.commands.push('(');
				sequence(fn.params, state, false, handle);
				state.commands.push(') ');

				handle(fn.body, state);
			} else {
				handle(p, state);
			}
		});
		state.commands.push('}');
	},

	ObjectPattern(node, state) {
		state.commands.push('{');
		sequence(node.properties, state, true, handle);
		state.commands.push('}');

		if (node.typeAnnotation) handle_type_annotation(node.typeAnnotation, state);
	},

	// @ts-expect-error this isn't a real node type, but Acorn produces it
	ParenthesizedExpression(node, state) {
		return handle(node.expression, state);
	},

	PrivateIdentifier(node, state) {
		state.commands.push('#', c(node.name, node));
	},

	Program(node, state) {
		handle_body(node.body, state);
	},

	Property(node, state) {
		const value = node.value.type === 'AssignmentPattern' ? node.value.left : node.value;

		const shorthand =
			!node.computed &&
			node.kind === 'init' &&
			node.key.type === 'Identifier' &&
			value.type === 'Identifier' &&
			node.key.name === value.name;

		if (shorthand) {
			handle(node.value, state);
			return;
		}

		if (node.computed) state.commands.push('[');
		handle(node.key, state);
		state.commands.push(node.computed ? ']: ' : ': ');
		handle(node.value, state);
	},

	PropertyDefinition(node, state) {
		if (node.decorators) {
			for (const decorator of node.decorators) {
				handle(decorator, state);
			}
		}

		if (node.accessibility) {
			state.commands.push(node.accessibility, ' ');
		}

		if (node.static) {
			state.commands.push('static ');
		}

		if (node.computed) {
			state.commands.push('[');
			handle(node.key, state);
			state.commands.push(']');
		} else {
			handle(node.key, state);
		}

		if (node.typeAnnotation) {
			state.commands.push(': ');
			handle_type_annotation(node.typeAnnotation.typeAnnotation, state);
		}

		if (node.value) {
			state.commands.push(' = ');

			handle(node.value, state);
		}

		state.commands.push(';');
	},

	RestElement: shared['RestElement|SpreadElement'],

	ReturnStatement(node, state) {
		if (node.argument) {
			const argumentWithComment = /** @type {NodeWithComments} */ (node.argument);
			const contains_comment =
				argumentWithComment.leadingComments &&
				argumentWithComment.leadingComments.some((comment) => comment.type === 'Line');

			state.commands.push(contains_comment ? 'return (' : 'return ');
			handle(node.argument, state);
			state.commands.push(contains_comment ? ');' : ';');
		} else {
			state.commands.push('return;');
		}
	},

	SequenceExpression(node, state) {
		state.commands.push('(');
		sequence(node.expressions, state, false, handle);
		state.commands.push(')');
	},

	SpreadElement: shared['RestElement|SpreadElement'],

	StaticBlock(node, state) {
		state.commands.push(indent, 'static {', newline);

		handle_body(node.body, state);

		state.commands.push(dedent, newline, '}');
	},

	Super(node, state) {
		state.commands.push(c('super', node));
	},

	SwitchStatement(node, state) {
		state.commands.push('switch (');
		handle(node.discriminant, state);
		state.commands.push(') {', indent);

		let first = true;

		for (const block of node.cases) {
			if (!first) state.commands.push('\n');
			first = false;

			if (block.test) {
				state.commands.push(newline, `case `);
				handle(block.test, state);
				state.commands.push(':');
			} else {
				state.commands.push(newline, `default:`);
			}

			state.commands.push(indent);

			for (const statement of block.consequent) {
				state.commands.push(newline);
				handle(statement, state);
			}

			state.commands.push(dedent);
		}

		state.commands.push(dedent, newline, `}`);
	},

	TaggedTemplateExpression(node, state) {
		handle(node.tag, state);
		handle(node.quasi, state);
	},

	TemplateLiteral(node, state) {
		state.commands.push('`');

		const { quasis, expressions } = node;

		for (let i = 0; i < expressions.length; i++) {
			const raw = quasis[i].value.raw;

			state.commands.push(raw, '${');
			handle(expressions[i], state);
			state.commands.push('}');

			if (/\n/.test(raw)) state.multiline = true;
		}

		const raw = quasis[quasis.length - 1].value.raw;

		state.commands.push(raw, '`');
		if (/\n/.test(raw)) state.multiline = true;
	},

	ThisExpression(node, state) {
		state.commands.push(c('this', node));
	},

	ThrowStatement(node, state) {
		state.commands.push('throw ');
		if (node.argument) handle(node.argument, state);
		state.commands.push(';');
	},

	TryStatement(node, state) {
		state.commands.push('try ');
		handle(node.block, state);

		if (node.handler) {
			if (node.handler.param) {
				state.commands.push(' catch(');
				handle(node.handler.param, state);
				state.commands.push(') ');
			} else {
				state.commands.push(' catch ');
			}

			handle(node.handler.body, state);
		}

		if (node.finalizer) {
			state.commands.push(' finally ');
			handle(node.finalizer, state);
		}
	},

	TSAsExpression(node, state) {
		if (node.expression) {
			const needs_parens =
				EXPRESSIONS_PRECEDENCE[node.expression.type] < EXPRESSIONS_PRECEDENCE.TSAsExpression;

			if (needs_parens) {
				state.commands.push('(');
				handle(node.expression, state);
				state.commands.push(')');
			} else {
				handle(node.expression, state);
			}
		}
		state.commands.push(' as ');
		handle_type_annotation(node.typeAnnotation, state);
	},

	TSEnumDeclaration(node, state) {
		state.commands.push('enum ');
		handle(node.id, state);
		state.commands.push(' {', indent, newline);
		sequence(node.members, state, false, handle_type_annotation);
		state.commands.push(dedent, newline, '}', newline);
	},

	TSModuleBlock(node, state) {
		state.commands.push(' {', indent, newline);
		handle_body(node.body, state);
		state.commands.push(dedent, newline, '}');
	},

	TSModuleDeclaration(node, state) {
		if (node.declare) state.commands.push('declare ');
		else state.commands.push('namespace ');

		handle(node.id, state);

		if (!node.body) return;
		handle(node.body, state);
	},

	TSNonNullExpression(node, state) {
		handle(node.expression, state);
		state.commands.push('!');
	},

	TSInterfaceBody(node, state) {
		sequence(node.body, state, true, handle_type_annotation, ';');
	},

	TSInterfaceDeclaration(node, state) {
		state.commands.push('interface ');
		handle(node.id, state);
		if (node.typeParameters) handle_type_annotation(node.typeParameters, state);
		if (node.extends) {
			state.commands.push(' extends ');
			sequence(node.extends, state, false, handle_type_annotation);
		}
		state.commands.push(' {');
		handle(node.body, state);
		state.commands.push('}');
	},

	TSSatisfiesExpression(node, state) {
		if (node.expression) {
			const needs_parens =
				EXPRESSIONS_PRECEDENCE[node.expression.type] < EXPRESSIONS_PRECEDENCE.TSSatisfiesExpression;

			if (needs_parens) {
				state.commands.push('(');
				handle(node.expression, state);
				state.commands.push(')');
			} else {
				handle(node.expression, state);
			}
		}
		state.commands.push(' satisfies ');
		handle_type_annotation(node.typeAnnotation, state);
	},

	TSTypeAliasDeclaration(node, state) {
		state.commands.push('type ');
		handle(node.id, state);
		if (node.typeParameters) handle_type_annotation(node.typeParameters, state);
		state.commands.push(' = ');
		handle_type_annotation(node.typeAnnotation, state);
		state.commands.push(';');
	},

	TSQualifiedName(node, state) {
		handle(node.left, state);
		state.commands.push('.');
		handle(node.right, state);
	},

	UnaryExpression(node, state) {
		state.commands.push(node.operator);

		if (node.operator.length > 1) {
			state.commands.push(' ');
		}

		if (EXPRESSIONS_PRECEDENCE[node.argument.type] < EXPRESSIONS_PRECEDENCE.UnaryExpression) {
			state.commands.push('(');
			handle(node.argument, state);
			state.commands.push(')');
		} else {
			handle(node.argument, state);
		}
	},

	UpdateExpression(node, state) {
		if (node.prefix) {
			state.commands.push(node.operator);
			handle(node.argument, state);
		} else {
			handle(node.argument, state);
			state.commands.push(node.operator);
		}
	},

	VariableDeclaration(node, state) {
		handle_var_declaration(node, state);
		state.commands.push(';');
	},

	VariableDeclarator(node, state) {
		handle(node.id, state);

		if (node.init) {
			state.commands.push(' = ');
			handle(node.init, state);
		}
	},

	WhileStatement(node, state) {
		state.commands.push('while (');
		handle(node.test, state);
		state.commands.push(') ');
		handle(node.body, state);
	},

	WithStatement(node, state) {
		state.commands.push('with (');
		handle(node.object, state);
		state.commands.push(') ');
		handle(node.body, state);
	},

	YieldExpression(node, state) {
		if (node.argument) {
			state.commands.push(node.delegate ? `yield* ` : `yield `);
			handle(node.argument, state);
		} else {
			state.commands.push(node.delegate ? `yield*` : `yield`);
		}
	}
};
