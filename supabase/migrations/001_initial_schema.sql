-- ============================================================
-- Schéma Supabase pour Rappels
-- Exécuter dans Supabase SQL Editor après création du projet
-- ============================================================

-- Extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Trigger pour updated_at automatique
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ─── Lists ────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS lists (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    color TEXT NOT NULL DEFAULT '#4B50E0',
    icon TEXT NOT NULL DEFAULT 'checklist',
    is_pinned INTEGER NOT NULL DEFAULT 0,
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMPTZ
);

CREATE INDEX idx_lists_user_id ON lists(user_id);
CREATE INDEX idx_lists_updated_at ON lists(updated_at);
CREATE INDEX idx_lists_user_id_updated_at ON lists(user_id, updated_at);

CREATE TRIGGER trg_lists_updated_at
    BEFORE UPDATE ON lists
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ─── Reminders ────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS reminders (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    list_id UUID NOT NULL REFERENCES lists(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    notes TEXT NOT NULL DEFAULT '',
    is_completed INTEGER NOT NULL DEFAULT 0,
    priority INTEGER NOT NULL DEFAULT 0,
    due_date DATE,
    has_time INTEGER NOT NULL DEFAULT 0,
    due_time TEXT,
    section TEXT,
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    completed_at TIMESTAMPTZ,
    deleted_at TIMESTAMPTZ
);

CREATE INDEX idx_reminders_user_id ON reminders(user_id);
CREATE INDEX idx_reminders_list_id ON reminders(list_id);
CREATE INDEX idx_reminders_updated_at ON reminders(updated_at);
CREATE INDEX idx_reminders_user_id_updated_at ON reminders(user_id, updated_at);

CREATE TRIGGER trg_reminders_updated_at
    BEFORE UPDATE ON reminders
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ─── Subtasks ─────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS subtasks (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    reminder_id UUID NOT NULL REFERENCES reminders(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    is_completed INTEGER NOT NULL DEFAULT 0,
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMPTZ
);

CREATE INDEX idx_subtasks_user_id ON subtasks(user_id);
CREATE INDEX idx_subtasks_reminder_id ON subtasks(reminder_id);
CREATE INDEX idx_subtasks_updated_at ON subtasks(updated_at);

CREATE TRIGGER trg_subtasks_updated_at
    BEFORE UPDATE ON subtasks
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ─── Tags ─────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS tags (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMPTZ,
    UNIQUE(user_id, name)
);

CREATE INDEX idx_tags_user_id ON tags(user_id);
CREATE INDEX idx_tags_updated_at ON tags(updated_at);

CREATE TRIGGER trg_tags_updated_at
    BEFORE UPDATE ON tags
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ─── Reminder-Tags (many-to-many) ────────────────────────────
CREATE TABLE IF NOT EXISTS reminder_tags (
    reminder_id UUID NOT NULL REFERENCES reminders(id) ON DELETE CASCADE,
    tag_id UUID NOT NULL REFERENCES tags(id) ON DELETE CASCADE,
    PRIMARY KEY (reminder_id, tag_id)
);

CREATE INDEX idx_reminder_tags_reminder ON reminder_tags(reminder_id);
CREATE INDEX idx_reminder_tags_tag ON reminder_tags(tag_id);

-- ─── RLS (Row Level Security) ────────────────────────────────
ALTER TABLE lists ENABLE ROW LEVEL SECURITY;
ALTER TABLE reminders ENABLE ROW LEVEL SECURITY;
ALTER TABLE subtasks ENABLE ROW LEVEL SECURITY;
ALTER TABLE tags ENABLE ROW LEVEL SECURITY;
ALTER TABLE reminder_tags ENABLE ROW LEVEL SECURITY;

-- Politique : chaque utilisateur ne voit que ses propres données
CREATE POLICY "Users can CRUD their own lists"
    ON lists FOR ALL
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can CRUD their own reminders"
    ON reminders FOR ALL
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can CRUD their own subtasks"
    ON subtasks FOR ALL
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can CRUD their own tags"
    ON tags FOR ALL
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

-- Pour reminder_tags, on vérifie via la table reminders
CREATE POLICY "Users can CRUD their own reminder_tags"
    ON reminder_tags FOR ALL
    USING (
        auth.uid() = (SELECT user_id FROM reminders WHERE id = reminder_id)
    )
    WITH CHECK (
        auth.uid() = (SELECT user_id FROM reminders WHERE id = reminder_id)
    );

-- ─── Realtime ─────────────────────────────────────────────────
-- Activer REPLICA IDENTITY FULL pour que Realtime envoie les rangées complètes
ALTER TABLE lists REPLICA IDENTITY FULL;
ALTER TABLE reminders REPLICA IDENTITY FULL;
ALTER TABLE subtasks REPLICA IDENTITY FULL;
ALTER TABLE tags REPLICA IDENTITY FULL;
ALTER TABLE reminder_tags REPLICA IDENTITY FULL;
