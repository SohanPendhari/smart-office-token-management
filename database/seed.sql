-- Smart Office Queue: seed data. Safe to re-run.
-- Default passwords:  admin -> Admin@123   staff -> Staff@123   (stored as bcrypt hashes)

INSERT INTO departments (id, name, code) VALUES
    (1, 'IT Support',     'IT'),
    (2, 'HR',             'HR'),
    (3, 'Accounts',       'ACC'),
    (4, 'Administration', 'ADM')
ON CONFLICT (id) DO NOTHING;
SELECT setval(pg_get_serial_sequence('departments', 'id'), GREATEST((SELECT MAX(id) FROM departments), 1));

INSERT INTO queue_settings (department_id, avg_service_minutes, max_no_shows, allow_visitor_priority)
SELECT id, 5, 2, TRUE FROM departments
ON CONFLICT (department_id) DO NOTHING;

INSERT INTO users (name, email, password_hash, role, department_id) VALUES
    ('Admin',            'admin@smartoffice.com',          '$2a$10$9o4y2IFvSAy2G7E.ayHEx.ZB0ZLPhXzwEfjaGVFGYx9mgREnF9Dfq', 'ADMIN', NULL),
    ('IT Staff',         'it.staff@smartoffice.com',       '$2a$10$ImdQ8iAT4g0lfbHn/19SfexqWrld.NTgH5Z2DE9jp/u83qTAIOdsu', 'STAFF', 1),
    ('HR Staff',         'hr.staff@smartoffice.com',       '$2a$10$ImdQ8iAT4g0lfbHn/19SfexqWrld.NTgH5Z2DE9jp/u83qTAIOdsu', 'STAFF', 2),
    ('Accounts Staff',   'accounts.staff@smartoffice.com', '$2a$10$ImdQ8iAT4g0lfbHn/19SfexqWrld.NTgH5Z2DE9jp/u83qTAIOdsu', 'STAFF', 3),
    ('Admin Dept Staff', 'admin.staff@smartoffice.com',    '$2a$10$ImdQ8iAT4g0lfbHn/19SfexqWrld.NTgH5Z2DE9jp/u83qTAIOdsu', 'STAFF', 4)
ON CONFLICT (LOWER(email)) DO NOTHING;

-- One counter per department, assigned to that department's staff member.
INSERT INTO counters (department_id, name, assigned_user_id)
SELECT d.id, 'Counter 1', u.id
FROM departments d
LEFT JOIN users u ON u.department_id = d.id AND u.role = 'STAFF'
ON CONFLICT (department_id, name) DO NOTHING;
