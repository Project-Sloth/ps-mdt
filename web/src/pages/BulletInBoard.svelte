<script lang="ts">
    import { onMount } from "svelte";
    import { fetchNui } from "../utils/fetchNui";
    import { NUI_EVENTS } from "../constants/nuiEvents";
    import type { AuthService } from "../services/authService.svelte";

    // ── Types ──────────────────────────────────────────────────

    interface BulletinPost {
        id: number;
        title: string;
        content: string;
        author: string;
        author_rank: string;
        category: string;
        category_label?: string;
        category_color?: string;
        priority: BulletinPriority;
        pinned: boolean;
        created_by: string;
        created_at: string;
        updated_at?: string;
    }

    interface SidebarCategory {
        value: string;
        label: string;
        icon: string;
        color: string;
        sort_order?: number;
        is_default?: boolean;
    }

    type BulletinPriority = 'low' | 'normal' | 'high' | 'urgent';

    interface ModalState {
        open: boolean;
        mode: 'create' | 'edit';
        post: Partial<BulletinPost>;
    }

    let { authService }: { authService?: AuthService } = $props();

    // ── Constants ──────────────────────────────────────────────

    const STATIC_ALL_CATEGORY: SidebarCategory = {
        label: 'All Posts', icon: 'dashboard', value: 'all', color: '#6B7280'
    };

    const PRIORITY_META: Record<BulletinPriority, { label: string; icon: string; color: string }> = {
        low:    { label: 'Low',    icon: 'arrow_downward', color: 'rgba(100,200,100,0.80)' },
        normal: { label: 'Normal', icon: 'remove',         color: 'rgba(160,160,210,0.80)' },
        high:   { label: 'High',   icon: 'arrow_upward',   color: 'rgba(240,180,40,0.90)'  },
        urgent: { label: 'Urgent', icon: 'priority_high',  color: 'rgba(220,70,60,0.95)'   },
    };

    // ── State ──────────────────────────────────────────────────

    let posts           = $state<BulletinPost[]>([]);
    let categories      = $state<SidebarCategory[]>([]);
    let loading         = $state(true);
    let saving          = $state(false);
    let searchQuery     = $state('');
    let activeCategory  = $state('all');
    let expandedId      = $state<number | null>(null);

    let modal = $state<ModalState>({
        open: false,
        mode: 'create',
        post: defaultPost(),
    });

    let deleteConfirm = $state<{ open: boolean; postId: number | null }>({
        open: false,
        postId: null,
    });

    // ── Derived ────────────────────────────────────────────────

    let sidebarCategories = $derived([STATIC_ALL_CATEGORY, ...categories]);

    let activeCatMeta = $derived(
        sidebarCategories.find(c => c.value === activeCategory) ?? STATIC_ALL_CATEGORY
    );

    let pinnedPosts = $derived(
        posts.filter(p =>
            p.pinned &&
            (activeCategory === 'all' || p.category === activeCategory) &&
            matchesSearch(p)
        )
    );

    let regularPosts = $derived(() => {
        const base = posts.filter(p =>
            !p.pinned &&
            (activeCategory === 'all' || p.category === activeCategory) &&
            matchesSearch(p)
        );
        const order: Record<BulletinPriority, number> = { urgent: 0, high: 1, normal: 2, low: 3 };
        return base.sort((a, b) => {
            const pd = order[a.priority] - order[b.priority];
            return pd !== 0 ? pd : new Date(b.created_at).getTime() - new Date(a.created_at).getTime();
        });
    });

    let postCountFor = $derived((cat: string) =>
        cat === 'all'
            ? posts.length
            : posts.filter(p => p.category === cat).length
    );

    // ── Helpers ────────────────────────────────────────────────

    function defaultPost(): Partial<BulletinPost> {
        const firstCat = categories[0]?.value ?? 'general';
        return { title: '', content: '', category: firstCat, priority: 'normal', pinned: false };
    }

    function matchesSearch(p: BulletinPost): boolean {
        const q = searchQuery.toLowerCase().trim();
        if (!q) return true;
        return (
            p.title.toLowerCase().includes(q) ||
            p.content.toLowerCase().includes(q) ||
            p.author.toLowerCase().includes(q)
        );
    }

    function formatDate(dateStr: string): string {
        try {
            const d = new Date(dateStr);
            return d.toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' }) +
                   ' · ' +
                   d.toLocaleTimeString('de-DE', { hour: '2-digit', minute: '2-digit' });
        } catch { return dateStr; }
    }

    function getCategoryMeta(value: string): SidebarCategory {
        return categories.find(c => c.value === value) ?? {
            value,
            label: value,
            icon: 'label',
            color: '#6B7280',
        };
    }

    function canEdit(_post: BulletinPost): boolean {
        return authService?.hasPermission?.('bulletin_post') || false;
    }

    function canPost(): boolean {
        return authService?.hasPermission?.('bulletin_post') || false;
    }

    function canPin(): boolean {
        return authService?.hasPermission?.('bulletin_pin') || false;
    }

    // ── Data loading ───────────────────────────────────────────

    onMount(async () => {
        await loadCategories();
        await loadPosts();
    });

    async function loadCategories() {
        try {
            const result = await fetchNui<SidebarCategory[]>(NUI_EVENTS.BULLETIN.GET_CATEGORIES, {}, []);
            if (Array.isArray(result) && result.length > 0) {
                categories = result;
            }
        } catch {
            // keep empty, posts still load fine
        }
    }

    async function loadPosts() {
        loading = true;
        try {
            const result = await fetchNui<BulletinPost[]>(NUI_EVENTS.BULLETIN.GET_POSTS, {}, []);
            posts = result || [];
        } catch {
            posts = [];
        } finally {
            loading = false;
        }
    }

    // ── CRUD actions ───────────────────────────────────────────

    function openCreate() {
        modal = { open: true, mode: 'create', post: defaultPost() };
    }

    function openEdit(post: BulletinPost) {
        modal = { open: true, mode: 'edit', post: { ...post } };
    }

    function closeModal() {
        modal = { open: false, mode: 'create', post: defaultPost() };
    }

    async function savePost() {
        if (!modal.post.title?.trim() || !modal.post.content?.trim()) return;
        saving = true;
        try {
            if (modal.mode === 'create') {
                const res = await fetchNui<{ success: boolean; id?: number }>(
                    NUI_EVENTS.BULLETIN.CREATE_POST, modal.post, { success: false }
                );
                if (res?.success) { await loadPosts(); closeModal(); }
            } else {
                const res = await fetchNui<{ success: boolean }>(
                    NUI_EVENTS.BULLETIN.UPDATE_POST, modal.post, { success: false }
                );
                if (res?.success) { await loadPosts(); closeModal(); }
            }
        } finally {
            saving = false;
        }
    }

    function askDelete(postId: number) {
        deleteConfirm = { open: true, postId };
    }

    async function confirmDelete() {
        if (!deleteConfirm.postId) return;
        saving = true;
        try {
            await fetchNui(NUI_EVENTS.BULLETIN.DELETE_POST, { id: deleteConfirm.postId }, {});
            await loadPosts();
            deleteConfirm = { open: false, postId: null };
        } finally {
            saving = false;
        }
    }

    async function togglePin(post: BulletinPost) {
        await fetchNui(NUI_EVENTS.BULLETIN.TOGGLE_PIN, { id: post.id }, {});
        await loadPosts();
    }
</script>

<!-- ════════════════════════════════════════════════════════════
     Layout
═════════════════════════════════════════════════════════════ -->
<div class="bulletin-page">

    <!-- ── Sidebar ── -->
    <div class="bulletin-sidebar">
        <div class="sidebar-header">
            <span class="material-icons header-icon">campaign</span>
            <h2>Bulletin Board</h2>
        </div>

        <div class="search-box">
            <span class="material-icons search-icon">search</span>
            <input type="text" placeholder="Search posts..." bind:value={searchQuery} />
        </div>

        <div class="category-list">
            {#each sidebarCategories as cat}
                {@const count = postCountFor(cat.value)}
                <button
                    class="category-item"
                    class:active={activeCategory === cat.value}
                    onclick={() => activeCategory = cat.value}
                    style={activeCategory === cat.value && cat.value !== 'all'
                        ? `--cat-color: ${cat.color};`
                        : ''}
                >
                    <!-- Colored dot for non-"all" categories -->
                    {#if cat.value !== 'all'}
                        <span
                            class="cat-color-dot"
                            style="background:{cat.color};"
                        ></span>
                    {/if}
                    <span
                        class="material-icons cat-icon"
                        style={activeCategory === cat.value && cat.value !== 'all' ? `color:${cat.color};` : ''}
                    >{cat.icon}</span>
                    <div class="cat-info">
                        <span class="cat-title">{cat.label}</span>
                        <span class="cat-count">{count} post{count !== 1 ? 's' : ''}</span>
                    </div>
                    {#if activeCategory === cat.value && cat.value !== 'all'}
                        <span
                            class="cat-active-bar"
                            style="background:{cat.color};"
                        ></span>
                    {/if}
                </button>
            {/each}
        </div>

        <div class="sidebar-footer">
            {#if canPost()}
                <button class="create-btn" onclick={openCreate}>
                    <span class="material-icons">add</span>
                    New Post
                </button>
            {/if}
        </div>
    </div>

    <!-- ── Main Content ── -->
    <div class="bulletin-content">

        <!-- Active category header bar -->
        {#if activeCategory !== 'all'}
            <div
                class="content-cat-header"
                style="border-left-color:{activeCatMeta.color}; background:linear-gradient(90deg, {activeCatMeta.color}12, transparent);"
            >
                <span class="material-icons" style="color:{activeCatMeta.color}; font-size:16px;">{activeCatMeta.icon}</span>
                <span class="content-cat-title" style="color:{activeCatMeta.color};">{activeCatMeta.label}</span>
                <span class="content-cat-sep">·</span>
                <span class="content-cat-count">{postCountFor(activeCategory)} post{postCountFor(activeCategory) !== 1 ? 's' : ''}</span>
            </div>
        {/if}

        {#if loading}
            <div class="content-empty">
                <div class="spinner"></div>
                <span>Loading bulletin board...</span>
            </div>

        {:else if posts.length === 0}
            <div class="content-empty">
                <span class="material-icons empty-icon">campaign</span>
                <h3>No Posts Yet</h3>
                <p>Be the first to post on the bulletin board.</p>
            </div>

        {:else}

            <!-- Pinned Posts -->
            {#if pinnedPosts.length > 0}
                <div class="section-label">
                    <span class="material-icons label-icon">push_pin</span>
                    <span>Pinned</span>
                </div>
                <div class="posts-list">
                    {#each pinnedPosts as post (post.id)}
                        {@const catMeta = getCategoryMeta(post.category)}
                        <div class="post-card pinned" class:expanded={expandedId === post.id}
                             style="--post-cat-color:{catMeta.color};">
                            <button class="post-header" onclick={() => expandedId = expandedId === post.id ? null : post.id}>
                                <div class="post-header-left">
                                    <span
                                        class="priority-badge"
                                        style="color:{PRIORITY_META[post.priority].color};border-color:{PRIORITY_META[post.priority].color};"
                                    >
                                        <span class="material-icons prio-icon">{PRIORITY_META[post.priority].icon}</span>
                                        {PRIORITY_META[post.priority].label}
                                    </span>
                                    <h3 class="post-title">{post.title}</h3>
                                </div>
                                <div class="post-header-right">
                                    <span class="material-icons pin-icon" style="color:{catMeta.color}40;">push_pin</span>
                                    <span class="material-icons expand-icon">{expandedId === post.id ? 'expand_less' : 'expand_more'}</span>
                                </div>
                            </button>

                            <div class="post-meta">
                                <span class="material-icons meta-icon">person</span>
                                <span class="meta-author">{post.author}</span>
                                {#if post.author_rank}
                                    <span class="meta-rank">{post.author_rank}</span>
                                {/if}
                                <span class="meta-sep">·</span>
                                <!-- Category tag with color -->
                                <span
                                    class="meta-cat-tag"
                                    style="color:{catMeta.color};background:{catMeta.color}12;border-color:{catMeta.color}25;"
                                >
                                    <span class="material-icons" style="font-size:10px;">{catMeta.icon}</span>
                                    {post.category_label ?? catMeta.label}
                                </span>
                                <span class="meta-sep">·</span>
                                <span class="material-icons meta-icon">schedule</span>
                                <span class="meta-date">{formatDate(post.created_at)}</span>
                            </div>

                            {#if expandedId === post.id}
                                <div class="post-body prose">
                                    {@html post.content}
                                </div>
                                <div class="post-actions">
                                    {#if canPin()}
                                        <button class="action-btn pin" onclick={() => togglePin(post)}>
                                            <span class="material-icons">push_pin</span>
                                            Unpin
                                        </button>
                                    {/if}
                                    {#if canEdit(post)}
                                        <button class="action-btn edit" onclick={() => openEdit(post)}>
                                            <span class="material-icons">edit</span>
                                            Edit
                                        </button>
                                    {/if}
                                    <button class="action-btn delete" onclick={() => askDelete(post.id)}>
                                        <span class="material-icons">delete</span>
                                        Delete
                                    </button>
                                </div>
                            {/if}
                        </div>
                    {/each}
                </div>
            {/if}

            <!-- Regular Posts -->
            {#if regularPosts().length > 0}
                <div class="section-label" style="margin-top: {pinnedPosts.length > 0 ? '16px' : '0'};">
                    <span class="material-icons label-icon">article</span>
                    <span>Posts</span>
                </div>
                <div class="posts-list">
                    {#each regularPosts() as post (post.id)}
                        {@const catMeta = getCategoryMeta(post.category)}
                        <div class="post-card" class:expanded={expandedId === post.id}
                             style="--post-cat-color:{catMeta.color};">
                            <!-- Left color accent bar -->
                            <div class="post-cat-bar" style="background:{catMeta.color};"></div>

                            <button class="post-header" onclick={() => expandedId = expandedId === post.id ? null : post.id}>
                                <div class="post-header-left">
                                    <span
                                        class="priority-badge"
                                        style="color:{PRIORITY_META[post.priority].color};border-color:{PRIORITY_META[post.priority].color};"
                                    >
                                        <span class="material-icons prio-icon">{PRIORITY_META[post.priority].icon}</span>
                                        {PRIORITY_META[post.priority].label}
                                    </span>
                                    <h3 class="post-title">{post.title}</h3>
                                </div>
                                <span class="material-icons expand-icon">{expandedId === post.id ? 'expand_less' : 'expand_more'}</span>
                            </button>

                            <div class="post-meta">
                                <span class="material-icons meta-icon">person</span>
                                <span class="meta-author">{post.author}</span>
                                {#if post.author_rank}
                                    <span class="meta-rank">{post.author_rank}</span>
                                {/if}
                                <span class="meta-sep">·</span>
                                <!-- Category tag with color -->
                                <span
                                    class="meta-cat-tag"
                                    style="color:{catMeta.color};background:{catMeta.color}12;border-color:{catMeta.color}25;"
                                >
                                    <span class="material-icons" style="font-size:10px;">{catMeta.icon}</span>
                                    {post.category_label ?? catMeta.label}
                                </span>
                                <span class="meta-sep">·</span>
                                <span class="material-icons meta-icon">schedule</span>
                                <span class="meta-date">{formatDate(post.created_at)}</span>
                            </div>

                            {#if expandedId === post.id}
                                <div class="post-body prose">
                                    {@html post.content}
                                </div>
                                <div class="post-actions">
                                    {#if canPin()}
                                        <button class="action-btn pin" onclick={() => togglePin(post)}>
                                            <span class="material-icons">push_pin</span>
                                            Pin
                                        </button>
                                    {/if}
                                    {#if canEdit(post)}
                                        <button class="action-btn edit" onclick={() => openEdit(post)}>
                                            <span class="material-icons">edit</span>
                                            Edit
                                        </button>
                                    {/if}
                                    <button class="action-btn delete" onclick={() => askDelete(post.id)}>
                                        <span class="material-icons">delete</span>
                                        Delete
                                    </button>
                                </div>
                            {/if}
                        </div>
                    {/each}
                </div>
            {:else if pinnedPosts.length === 0}
                <div class="content-empty">
                    <span class="material-icons empty-icon">search_off</span>
                    <h3>No posts found</h3>
                    <p>Try adjusting your search or category filter.</p>
                </div>
            {/if}
        {/if}
    </div>
</div>

<!-- ════════════════════════════════════════════════════════════
     Create / Edit Modal
═════════════════════════════════════════════════════════════ -->
{#if modal.open}
    <div class="modal-backdrop" onclick={closeModal}>
        <div class="modal" onclick={(e) => e.stopPropagation()}>
            <div class="modal-header">
                <span class="material-icons modal-header-icon">
                    {modal.mode === 'create' ? 'add_circle' : 'edit'}
                </span>
                <h3>{modal.mode === 'create' ? 'New Bulletin Post' : 'Edit Post'}</h3>
                <button class="close-btn" onclick={closeModal} aria-label="Close">
                    <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                        <line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/>
                    </svg>
                </button>
            </div>

            <div class="modal-body">
                <div class="form-group form-full">
                    <span class="field-label">Title <span class="required">*</span></span>
                    <input
                        class="form-input"
                        type="text"
                        placeholder="Post title..."
                        bind:value={modal.post.title}
                        maxlength="255"
                    />
                </div>

                <div class="form-group">
                    <span class="field-label">Category</span>
                    <select class="form-input form-select" bind:value={modal.post.category}>
                        {#each categories as cat}
                            <option value={cat.value}>{cat.label}</option>
                        {/each}
                    </select>
                    <!-- Color preview for selected category -->
                    {#if modal.post.category}
                        {@const selCat = getCategoryMeta(modal.post.category)}
                        <div class="cat-select-preview">
                            <span class="dot" style="background:{selCat.color};"></span>
                            <span class="material-icons" style="font-size:12px;color:{selCat.color};">{selCat.icon}</span>
                            <span style="color:{selCat.color}; font-size:10px;">{selCat.label}</span>
                        </div>
                    {/if}
                </div>

                <div class="form-group">
                    <span class="field-label">Priority</span>
                    <select class="form-input form-select" bind:value={modal.post.priority}>
                        <option value="low">Low</option>
                        <option value="normal">Normal</option>
                        <option value="high">High</option>
                        <option value="urgent">Urgent</option>
                    </select>
                </div>

                <div class="form-group form-full">
                    <span class="field-label">Content <span class="required">*</span></span>
                    <textarea
                        class="form-input"
                        placeholder="Write your post content here... (HTML supported)"
                        bind:value={modal.post.content}
                        rows="8"
                    ></textarea>
                    <span class="field-hint">Basic HTML tags are supported: &lt;b&gt;, &lt;ul&gt;, &lt;li&gt;, &lt;p&gt;, etc.</span>
                </div>

                {#if canPin()}
                    <div class="form-group form-full field-check">
                        <input type="checkbox" id="chk-pinned" bind:checked={modal.post.pinned} />
                        <label for="chk-pinned">
                            <span class="material-icons">push_pin</span>
                            Pin this post to the top
                        </label>
                    </div>
                {/if}
            </div>

            <div class="modal-footer">
                <button class="cancel-btn" onclick={closeModal} disabled={saving}>Cancel</button>
                <button
                    class="primary-btn"
                    onclick={savePost}
                    disabled={saving || !modal.post.title?.trim() || !modal.post.content?.trim()}
                >
                    {#if saving}
                        <div class="spinner-sm"></div>
                    {:else}
                        <span class="material-icons" style="font-size: 13px;">save</span>
                    {/if}
                    {modal.mode === 'create' ? 'Post' : 'Save Changes'}
                </button>
            </div>
        </div>
    </div>
{/if}

<!-- ════════════════════════════════════════════════════════════
     Delete Confirm Modal
═════════════════════════════════════════════════════════════ -->
{#if deleteConfirm.open}
    <div class="modal-backdrop" onclick={() => deleteConfirm = { open: false, postId: null }}>
        <div class="modal modal-sm" onclick={(e) => e.stopPropagation()}>
            <div class="modal-header">
                <span class="material-icons modal-header-icon" style="color: rgba(220,70,60,0.85);">warning</span>
                <h3>Delete Post</h3>
                <button class="close-btn" onclick={() => deleteConfirm = { open: false, postId: null }} aria-label="Close">
                    <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                        <line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/>
                    </svg>
                </button>
            </div>
            <div class="modal-body">
                <p class="confirm-text">Are you sure you want to delete this post? This action cannot be undone.</p>
            </div>
            <div class="modal-footer">
                <button class="cancel-btn" onclick={() => deleteConfirm = { open: false, postId: null }} disabled={saving}>Cancel</button>
                <button class="delete-btn" onclick={confirmDelete} disabled={saving}>
                    {#if saving}<div class="spinner-sm"></div>{:else}<span class="material-icons" style="font-size: 13px;">delete</span>{/if}
                    Delete
                </button>
            </div>
        </div>
    </div>
{/if}

<style>
    /* ── Layout ──────────────────────────────────────────────── */
    .bulletin-page { display: flex; height: 100%; overflow: hidden; }

    /* ── Sidebar ─────────────────────────────────────────────── */
    .bulletin-sidebar {
        width: 280px; min-width: 280px;
        border-right: 1px solid rgba(255,255,255,0.06);
        display: flex; flex-direction: column; overflow: hidden;
    }

    .sidebar-header {
        padding: 20px 20px 16px;
        display: flex; align-items: center; gap: 10px;
        border-bottom: 1px solid rgba(255,255,255,0.06);
        flex-shrink: 0;
    }

    .header-icon { font-size: 22px; color: var(--accent-70); }
    .sidebar-header h2 { font-size: 14px; font-weight: 600; color: rgba(255,255,255,0.9); margin: 0; }

    .search-box { padding: 12px 16px; position: relative; flex-shrink: 0; }
    .search-icon { position: absolute; left: 26px; top: 50%; transform: translateY(-50%); font-size: 16px; color: rgba(255,255,255,0.3); }
    .search-box input {
        width: 100%; padding: 8px 12px 8px 34px;
        background: rgba(255,255,255,0.04); border: 1px solid rgba(255,255,255,0.08);
        border-radius: 6px; color: rgba(255,255,255,0.9); font-size: 12px; outline: none; transition: border-color 0.15s;
    }
    .search-box input:focus { border-color: var(--accent-35); }
    .search-box input::placeholder { color: rgba(255,255,255,0.3); }

    .category-list {
        flex: 1; overflow-y: auto; padding: 4px 8px;
        scrollbar-width: thin; scrollbar-color: rgba(255,255,255,0.08) transparent;
    }

    .category-item {
        width: 100%; display: flex; align-items: center; gap: 10px;
        padding: 10px 12px;
        border: 1px solid transparent; background: transparent;
        border-radius: 6px; cursor: pointer; text-align: left;
        transition: all 0.15s; margin-bottom: 2px; outline: none;
        position: relative; overflow: hidden;
    }
    .category-item:hover:not(.active) { background: rgba(255,255,255,0.04); }
    .category-item.active {
        background: color-mix(in srgb, var(--cat-color, var(--accent-color)) 8%, transparent);
        border-color: color-mix(in srgb, var(--cat-color, var(--accent-color)) 20%, transparent);
    }

    .cat-color-dot {
        width: 6px; height: 6px; border-radius: 50%; flex-shrink: 0;
        opacity: 0.7;
    }

    .cat-active-bar {
        position: absolute; right: 0; top: 20%; bottom: 20%;
        width: 2px; border-radius: 2px 0 0 2px; opacity: 0.6;
    }

    .cat-icon { font-size: 18px; color: rgba(255,255,255,0.4); flex-shrink: 0; }

    .cat-info { display: flex; flex-direction: column; gap: 2px; min-width: 0; flex: 1; }
    .cat-title { font-size: 12px; font-weight: 500; color: rgba(255,255,255,0.8); white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
    .cat-count { font-size: 10px; color: rgba(255,255,255,0.35); }

    .sidebar-footer { padding: 12px 16px; border-top: 1px solid rgba(255,255,255,0.06); flex-shrink: 0; }

    .create-btn {
        width: 100%; display: flex; align-items: center; justify-content: center; gap: 6px;
        padding: 9px 14px; background: var(--accent-15); border: 1px solid var(--accent-30);
        border-radius: 6px; color: var(--accent-80, rgba(100,160,255,0.9));
        font-size: 12px; font-weight: 600; cursor: pointer; transition: all 0.15s; outline: none;
    }
    .create-btn:hover { background: var(--accent-20); border-color: var(--accent-45); }
    .create-btn .material-icons { font-size: 16px; }

    /* ── Main Content ────────────────────────────────────────── */
    .bulletin-content {
        flex: 1; overflow-y: auto; padding: 24px 32px;
        scrollbar-width: thin; scrollbar-color: rgba(255,255,255,0.08) transparent;
    }

    /* Category header bar */
    .content-cat-header {
        display: flex; align-items: center; gap: 8px;
        padding: 8px 14px; border-radius: 6px; border-left: 3px solid;
        margin-bottom: 18px;
    }
    .content-cat-title { font-size: 13px; font-weight: 600; }
    .content-cat-sep   { color: rgba(255,255,255,0.2); font-size: 12px; }
    .content-cat-count { font-size: 11px; color: rgba(255,255,255,0.4); }

    .content-empty {
        display: flex; flex-direction: column; align-items: center; justify-content: center;
        height: 100%; gap: 8px; color: rgba(255,255,255,0.4); text-align: center;
    }
    .empty-icon { font-size: 48px; color: rgba(255,255,255,0.15); margin-bottom: 8px; }
    .content-empty h3 { font-size: 16px; color: rgba(255,255,255,0.6); margin: 0; }
    .content-empty p  { font-size: 13px; color: rgba(255,255,255,0.35); margin: 0; }

    .section-label {
        display: flex; align-items: center; gap: 6px;
        font-size: 10px; font-weight: 700; text-transform: uppercase;
        letter-spacing: 0.8px; color: rgba(255,255,255,0.3); margin-bottom: 10px;
    }
    .label-icon { font-size: 13px; color: rgba(255,255,255,0.25); }

    .posts-list { display: flex; flex-direction: column; gap: 8px; margin-bottom: 8px; }

    /* ── Post cards ──────────────────────────────────────────── */
    .post-card {
        background: rgba(255,255,255,0.02);
        border: 1px solid transparent;
        border-radius: 10px; overflow: hidden; transition: border-color 0.15s;
        position: relative;
    }
    .post-card:hover { border-color: rgba(255,255,255,0.06); }

    /* Left accent bar (regular posts) */
    .post-cat-bar {
        position: absolute; left: 0; top: 0; bottom: 0;
        width: 3px; opacity: 0.5;
    }

    .post-card.pinned {
        background: rgba(59,130,246,0.07);
        border-color: rgba(59,130,246,0.18);
    }
    .post-card.pinned:hover { border-color: rgba(59,130,246,0.28); }

    .post-card.expanded { border-color: rgba(255,255,255,0.08); }
    .post-card.pinned.expanded { border-color: rgba(59,130,246,0.30); }

    .post-header {
        width: 100%; display: flex; align-items: center; justify-content: space-between; gap: 12px;
        padding: 12px 16px 12px 20px;
        background: transparent; border: none; cursor: pointer; text-align: left; outline: none;
    }
    .post-header-left  { display: flex; align-items: center; gap: 10px; min-width: 0; flex: 1; }
    .post-header-right { display: flex; align-items: center; gap: 6px; flex-shrink: 0; }

    .priority-badge {
        display: inline-flex; align-items: center; gap: 3px;
        padding: 2px 7px 2px 5px; border: 1px solid; border-radius: 4px;
        font-size: 10px; font-weight: 600; text-transform: uppercase;
        letter-spacing: 0.4px; flex-shrink: 0; white-space: nowrap;
    }
    .prio-icon { font-size: 11px; }

    .post-title {
        font-size: 13px; font-weight: 600; color: rgba(255,255,255,0.88);
        margin: 0; white-space: nowrap; overflow: hidden; text-overflow: ellipsis;
    }

    .pin-icon    { font-size: 14px; }
    .expand-icon { font-size: 18px; color: rgba(255,255,255,0.25); flex-shrink: 0; }

    /* Meta row */
    .post-meta {
        display: flex; align-items: center; gap: 5px;
        padding: 0 16px 10px; flex-wrap: wrap;
    }
    .meta-icon   { font-size: 12px; color: rgba(255,255,255,0.25); }
    .meta-author { font-size: 11px; font-weight: 500; color: rgba(255,255,255,0.55); }
    .meta-rank   {
        font-size: 10px; color: rgba(255,255,255,0.3);
        background: rgba(255,255,255,0.05); border: 1px solid rgba(255,255,255,0.07);
        border-radius: 3px; padding: 1px 5px;
    }
    .meta-sep  { color: rgba(255,255,255,0.18); font-size: 11px; }
    .meta-date { font-size: 11px; color: rgba(255,255,255,0.30); }

    .meta-cat-tag {
        display: inline-flex; align-items: center; gap: 3px;
        font-size: 10px; font-weight: 500;
        padding: 1px 6px; border-radius: 3px; border: 1px solid;
    }

    /* Post body */
    .post-body {
        padding: 14px 16px; border-top: 1px solid rgba(255,255,255,0.04);
        color: rgba(255,255,255,0.72); font-size: 12.5px; line-height: 1.7;
    }
    .post-body :global(h1), .post-body :global(h2), .post-body :global(h3) { color: rgba(255,255,255,0.9); margin: 12px 0 6px; }
    .post-body :global(h1) { font-size: 15px; }
    .post-body :global(h2) { font-size: 14px; }
    .post-body :global(h3) { font-size: 13px; }
    .post-body :global(p)  { margin: 5px 0; }
    .post-body :global(ul), .post-body :global(ol) { padding-left: 20px; margin: 5px 0; }
    .post-body :global(li) { margin: 3px 0; }
    .post-body :global(strong) { color: rgba(255,255,255,0.95); }

    /* Post actions */
    .post-actions {
        display: flex; align-items: center; gap: 6px;
        padding: 10px 16px 12px; border-top: 1px solid rgba(255,255,255,0.04);
    }

    .action-btn {
        display: inline-flex; align-items: center; gap: 4px;
        padding: 5px 10px; border-radius: 5px; font-size: 11px; font-weight: 500;
        cursor: pointer; border: 1px solid; transition: all 0.15s; outline: none;
    }
    .action-btn .material-icons { font-size: 13px; }
    .action-btn.pin  { color: var(--accent-70); background: var(--accent-08, rgba(59,130,246,0.08)); border-color: var(--accent-20); }
    .action-btn.pin:hover  { background: var(--accent-15); }
    .action-btn.edit { color: rgba(255,255,255,0.65); background: rgba(255,255,255,0.04); border-color: rgba(255,255,255,0.08); }
    .action-btn.edit:hover { color: rgba(255,255,255,0.9); background: rgba(255,255,255,0.07); }
    .action-btn.delete { color: rgba(220,70,60,0.85); background: rgba(220,70,60,0.06); border-color: rgba(220,70,60,0.18); margin-left: auto; }
    .action-btn.delete:hover { background: rgba(220,70,60,0.12); }

    /* ════ Modals ════════════════════════════════════════════ */
    .modal-backdrop {
        position: fixed; inset: 0; background: rgba(0,0,0,0.7);
        backdrop-filter: blur(4px); display: flex; align-items: center; justify-content: center; z-index: 100;
    }
    .modal {
        background: var(--card-dark-bg, #1a1c22); border: 1px solid rgba(255,255,255,0.06);
        border-radius: 6px; width: min(540px, 92vw); max-height: 85vh; overflow: hidden;
        display: flex; flex-direction: column; box-shadow: 0 20px 60px rgba(0,0,0,0.5);
    }
    .modal-sm { width: min(380px, 92vw); }

    .modal-header {
        display: flex; align-items: center; gap: 10px;
        padding: 10px 16px; border-bottom: 1px solid rgba(255,255,255,0.06); flex-shrink: 0;
    }
    .modal-header-icon { font-size: 16px; color: var(--accent-70); }
    .modal-header h3 { font-size: 12px; font-weight: 600; color: rgba(255,255,255,0.85); margin: 0; flex: 1; }

    .close-btn {
        display: flex; align-items: center; justify-content: center;
        background: transparent; color: rgba(255,255,255,0.3);
        border: 1px solid rgba(255,255,255,0.06); padding: 4px; border-radius: 3px;
        cursor: pointer; transition: all 0.1s; outline: none;
    }
    .close-btn:hover { color: rgba(255,255,255,0.7); border-color: rgba(255,255,255,0.1); }

    .modal-body {
        flex: 1; overflow-y: auto; padding: 14px 16px;
        display: grid; grid-template-columns: 1fr 1fr; gap: 10px; align-content: start;
        scrollbar-width: thin; scrollbar-color: rgba(255,255,255,0.08) transparent;
    }

    .form-group { display: flex; flex-direction: column; gap: 4px; }
    .form-full  { grid-column: 1 / -1; }

    .field-label { font-size: 9px; font-weight: 600; color: rgba(255,255,255,0.35); text-transform: uppercase; letter-spacing: 0.6px; }
    .required    { color: rgba(220,70,60,0.85); }

    .form-input {
        background: rgba(255,255,255,0.03); border: 1px solid rgba(255,255,255,0.06); border-radius: 3px;
        padding: 5px 8px; color: rgba(255,255,255,0.8); font-size: 11px; font-family: inherit; outline: none; transition: border-color 0.1s;
    }
    .form-input:focus { border-color: rgba(255,255,255,0.12); }
    .form-input::placeholder { color: rgba(255,255,255,0.2); }
    .form-select  { padding-right: 22px; cursor: pointer; }
    .form-select option { background: #1a1c22; }
    textarea.form-input { resize: vertical; min-height: 120px; line-height: 1.6; }

    .cat-select-preview {
        display: flex; align-items: center; gap: 5px; padding: 3px 0;
    }
    .cat-select-preview .dot { width: 8px; height: 8px; border-radius: 50%; flex-shrink: 0; }

    .field-hint  { font-size: 10px; color: rgba(255,255,255,0.25); }

    .field-check { display: flex; align-items: center; gap: 8px; }
    .field-check input[type="checkbox"] { accent-color: var(--accent-60); width: 14px; height: 14px; cursor: pointer; }
    .field-check label { display: flex; align-items: center; gap: 5px; font-size: 11px; color: rgba(255,255,255,0.6); cursor: pointer; }
    .field-check label .material-icons { font-size: 14px; color: var(--accent-60); }

    .confirm-text { font-size: 11px; color: rgba(255,255,255,0.6); margin: 0; line-height: 1.6; grid-column: 1 / -1; }

    .modal-footer {
        display: flex; align-items: center; justify-content: flex-end; gap: 6px;
        padding: 10px 16px; border-top: 1px solid rgba(255,255,255,0.06); flex-shrink: 0;
    }

    .cancel-btn {
        background: transparent; border: 1px solid rgba(255,255,255,0.06); border-radius: 3px;
        padding: 4px 12px; color: rgba(255,255,255,0.4); font-size: 10px; font-weight: 500; cursor: pointer; outline: none; transition: all 0.1s;
    }
    .cancel-btn:hover:not(:disabled) { color: rgba(255,255,255,0.7); border-color: rgba(255,255,255,0.1); }
    .cancel-btn:disabled { opacity: 0.3; cursor: not-allowed; }

    .primary-btn {
        display: flex; align-items: center; gap: 4px;
        background: rgba(16,185,129,0.06); border: 1px solid rgba(16,185,129,0.1); border-radius: 3px;
        padding: 4px 12px; color: rgba(52,211,153,0.7); font-size: 10px; font-weight: 600; cursor: pointer; outline: none; transition: all 0.1s;
    }
    .primary-btn:hover:not(:disabled) { background: rgba(16,185,129,0.12); color: rgba(110,231,183,0.9); }
    .primary-btn:disabled { opacity: 0.3; cursor: not-allowed; }

    .delete-btn {
        display: flex; align-items: center; gap: 4px;
        background: rgba(220,70,60,0.06); border: 1px solid rgba(220,70,60,0.18); border-radius: 3px;
        padding: 4px 12px; color: rgba(220,70,60,0.85); font-size: 10px; font-weight: 600; cursor: pointer; outline: none; transition: all 0.1s;
    }
    .delete-btn:hover:not(:disabled) { background: rgba(220,70,60,0.12); }
    .delete-btn:disabled { opacity: 0.3; cursor: not-allowed; }

    /* ── Spinners ─────────────────────────────────────────────── */
    .spinner {
        width: 24px; height: 24px;
        border: 2px solid rgba(255,255,255,0.06); border-left-color: var(--accent-60);
        border-radius: 50%; animation: spin 0.8s linear infinite; margin-bottom: 8px;
    }
    .spinner-sm {
        width: 11px; height: 11px;
        border: 2px solid rgba(255,255,255,0.1); border-left-color: currentColor;
        border-radius: 50%; animation: spin 0.8s linear infinite;
    }

    @keyframes spin { 0% { transform: rotate(0deg); } 100% { transform: rotate(360deg); } }
</style>