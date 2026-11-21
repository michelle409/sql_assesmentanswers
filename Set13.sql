CREATE EXTENSION IF NOT EXISTS citext;
-- SRM ALPHA PostgreSQL Assessment — SET 13
-- Scenario: Byju's - Online Learning Platform
-- Problem summary: Design a PostgreSQL schema for Byju's. A course has chapters, each with lessons (video + quiz). Students enroll in courses, watch lessons (track progress % per lesson), attempt quizzes (each quiz has questions with correct answers; attempts are scored). Teachers author courses; multiple teachers can co-author. Students can bookmark lessons and leave course ratings. Need: (a) a student's overall progress per course, (b) leaderboard of quiz scores per chapter, (c) teachers' authored-course list.
--
-- DESIGN NOTES
-- Tables and constraints below form a normalized relational model.
-- ON DELETE CASCADE is used for dependent/junction rows; RESTRICT protects
-- historical business records; SET NULL is used for optional references.
-- Indexes are chosen for the access patterns specified in the paper.
--
-- Byju's: Online Learning Platform
CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE TABLE teachers (teacher_id uuid PRIMARY KEY DEFAULT gen_random_uuid(), name text NOT NULL, email citext UNIQUE NOT NULL);
CREATE TABLE students (student_id uuid PRIMARY KEY DEFAULT gen_random_uuid(), name text NOT NULL, email citext UNIQUE NOT NULL);
CREATE TABLE courses (course_id uuid PRIMARY KEY DEFAULT gen_random_uuid(), title text NOT NULL, description text);
CREATE TABLE course_teachers (course_id uuid REFERENCES courses ON DELETE CASCADE, teacher_id uuid REFERENCES teachers ON DELETE RESTRICT, PRIMARY KEY(course_id,teacher_id));
CREATE TABLE enrollments (student_id uuid REFERENCES students ON DELETE CASCADE, course_id uuid REFERENCES courses ON DELETE CASCADE, enrolled_at timestamptz DEFAULT now(), PRIMARY KEY(student_id,course_id));
CREATE TABLE chapters (chapter_id uuid PRIMARY KEY DEFAULT gen_random_uuid(), course_id uuid NOT NULL REFERENCES courses ON DELETE CASCADE, title text NOT NULL, chapter_order integer NOT NULL, UNIQUE(course_id,chapter_order));
CREATE TABLE lessons (lesson_id uuid PRIMARY KEY DEFAULT gen_random_uuid(), chapter_id uuid NOT NULL REFERENCES chapters ON DELETE CASCADE, title text NOT NULL, video_url text, lesson_order integer NOT NULL, UNIQUE(chapter_id,lesson_order));
CREATE TABLE quizzes (quiz_id uuid PRIMARY KEY DEFAULT gen_random_uuid(), lesson_id uuid NOT NULL REFERENCES lessons ON DELETE CASCADE, title text NOT NULL);
CREATE TABLE quiz_questions (question_id uuid PRIMARY KEY DEFAULT gen_random_uuid(), quiz_id uuid NOT NULL REFERENCES quizzes ON DELETE CASCADE, prompt text NOT NULL, options jsonb NOT NULL, correct_answer jsonb NOT NULL);
CREATE TABLE lesson_progress (student_id uuid REFERENCES students ON DELETE CASCADE, lesson_id uuid REFERENCES lessons ON DELETE CASCADE, progress_percent numeric(5,2) NOT NULL DEFAULT 0 CHECK(progress_percent BETWEEN 0 AND 100), updated_at timestamptz DEFAULT now(), PRIMARY KEY(student_id,lesson_id));
CREATE TABLE quiz_attempts (attempt_id uuid PRIMARY KEY DEFAULT gen_random_uuid(), student_id uuid NOT NULL REFERENCES students ON DELETE CASCADE, quiz_id uuid NOT NULL REFERENCES quizzes ON DELETE CASCADE, score numeric(6,2) NOT NULL, attempted_at timestamptz DEFAULT now());
CREATE TABLE bookmarks (student_id uuid REFERENCES students ON DELETE CASCADE, lesson_id uuid REFERENCES lessons ON DELETE CASCADE, created_at timestamptz DEFAULT now(), PRIMARY KEY(student_id,lesson_id));
CREATE TABLE course_ratings (student_id uuid REFERENCES students ON DELETE CASCADE, course_id uuid REFERENCES courses ON DELETE CASCADE, rating smallint NOT NULL CHECK(rating BETWEEN 1 AND 5), PRIMARY KEY(student_id,course_id));
CREATE INDEX chapters_course_order_idx ON chapters(course_id,chapter_order);
CREATE INDEX lessons_chapter_order_idx ON lessons(chapter_id,lesson_order);
CREATE INDEX progress_student_idx ON lesson_progress(student_id,lesson_id);
CREATE INDEX quiz_attempts_quiz_score_idx ON quiz_attempts(quiz_id,score DESC);
CREATE INDEX course_teachers_teacher_idx ON course_teachers(teacher_id,course_id);
-- Trade-off: answer keys are stored for grading; protect quiz_questions.correct_answer with restricted privileges.


-- NORMALIZATION JUSTIFICATION
-- 1NF: Each table has a primary key and stores single/atomic values; repeating
--      collections (items, tags, memberships, etc.) are represented as child
--      or junction rows rather than repeating columns.
-- 2NF: Non-key attributes depend on the whole candidate key. In composite-key
--      junction/detail tables, attributes describe the complete relationship
--      (for example, quantity/price belongs to an order-item pair).
-- 3NF: Descriptive attributes are kept with their own entities; non-key
--      attributes are not intentionally stored as facts about another
--      non-key attribute. Historical snapshots are retained only where the
--      scenario explicitly requires them.
-- BCNF: BCNF is not claimed universally. It depends on all business
--      functional dependencies, including candidate keys, being known.
--      The schema is designed to reach at least 3NF; validate BCNF against
--      the complete real-world dependency set before claiming it.
