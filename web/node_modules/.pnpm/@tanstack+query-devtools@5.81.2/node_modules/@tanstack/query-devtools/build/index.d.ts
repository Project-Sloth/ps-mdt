import { Query, QueryClient, onlineManager } from '@tanstack/query-core';

type XPosition = 'left' | 'right';
type YPosition = 'top' | 'bottom';
type DevtoolsPosition = XPosition | YPosition;
type DevtoolsButtonPosition = `${YPosition}-${XPosition}` | 'relative';
interface DevtoolsErrorType {
    /**
     * The name of the error.
     */
    name: string;
    /**
     * How the error is initialized.
     */
    initializer: (query: Query) => Error;
}
interface QueryDevtoolsProps {
    readonly client: QueryClient;
    queryFlavor: string;
    version: string;
    onlineManager: typeof onlineManager;
    buttonPosition?: DevtoolsButtonPosition;
    position?: DevtoolsPosition;
    initialIsOpen?: boolean;
    errorTypes?: Array<DevtoolsErrorType>;
    shadowDOMTarget?: ShadowRoot;
    onClose?: () => unknown;
}

interface TanstackQueryDevtoolsConfig extends QueryDevtoolsProps {
    styleNonce?: string;
    shadowDOMTarget?: ShadowRoot;
}
declare class TanstackQueryDevtools {
    #private;
    constructor(config: TanstackQueryDevtoolsConfig);
    setButtonPosition(position: DevtoolsButtonPosition): void;
    setPosition(position: DevtoolsPosition): void;
    setInitialIsOpen(isOpen: boolean): void;
    setErrorTypes(errorTypes: Array<DevtoolsErrorType>): void;
    setClient(client: QueryClient): void;
    mount<T extends HTMLElement>(el: T): void;
    unmount(): void;
}

interface TanstackQueryDevtoolsPanelConfig extends QueryDevtoolsProps {
    styleNonce?: string;
    shadowDOMTarget?: ShadowRoot;
    onClose?: () => unknown;
}
declare class TanstackQueryDevtoolsPanel {
    #private;
    constructor(config: TanstackQueryDevtoolsPanelConfig);
    setButtonPosition(position: DevtoolsButtonPosition): void;
    setPosition(position: DevtoolsPosition): void;
    setInitialIsOpen(isOpen: boolean): void;
    setErrorTypes(errorTypes: Array<DevtoolsErrorType>): void;
    setClient(client: QueryClient): void;
    setOnClose(onClose: () => unknown): void;
    mount<T extends HTMLElement>(el: T): void;
    unmount(): void;
}

export { type DevtoolsButtonPosition, type DevtoolsErrorType, type DevtoolsPosition, TanstackQueryDevtools, type TanstackQueryDevtoolsConfig, TanstackQueryDevtoolsPanel, type TanstackQueryDevtoolsPanelConfig };
