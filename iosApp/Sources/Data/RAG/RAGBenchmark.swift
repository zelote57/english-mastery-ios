import Foundation

enum RAGBenchmark {
    static let version = "seeded-mistakes-v1"
    static let cases: [(skill: String, questionID: String, wrong: String, evidence: String)] = [
        ("A1-01", "8528b4b6-c30c-56d0-8414-24304e207431", "Me", "subject pronouns identify"),
        ("A1-02", "d73f7ea5-74cb-57c2-a5df-bd71fbb08fe0", "have", "when stating age"),
        ("A1-03", "a36061f8-1118-5587-bbcf-7f7341f14cb4", "a", "an apple"),
        ("A1-04", "871e661b-a9fd-5735-8e53-1a07f46b02cd", "boxs", "two boxes"),
        ("A1-05", "5bae8fc3-e37f-559e-9afc-25d553e38692", "go", "affirmative statements"),
        ("A2_INIT-01", "ce2f9a24-6d61-57d0-8315-f42e336ae3d9", "live", "Regular affirmative verbs"),
        ("A2_INIT-02", "19941540-3161-5e03-a4e4-c736517a13e7", "goed", "go/went"),
        ("A2_INIT-03", "f031e24a-42f4-5740-b701-acae869580a6", "since", "two days ago"),
        ("A2_INT-01", "a7aa537c-036e-54d6-954c-790f7510d479", "going to", "prediction based on present evidence"),
        ("A2_INT-02", "faeb809a-bf1f-562c-b1aa-f5056d06d067", "am going", "a decision made as you speak"),
        ("A2_INT-03", "c4ae8e35-8cf1-5cba-a059-613879a07306", "more fast", "faster than a bus"),
        ("A2_ADV-01", "20ecee91-86af-578d-a50a-24cdb4b6e926", "in", "with a clock time"),
        ("A2_ADV-02", "4ab4afe0-a0cb-5b69-adc6-d785c02fd5c2", "many", "uncountable nouns"),
        ("A2_ADV-03", "2ea564df-a7b1-590f-87e8-2dc68c455d08", "Can", "past ability"),
        ("B1_INIT-01", "946a7000-d93e-598b-930c-679315e5612e", "ago", "at any time"),
        ("B1_INIT-02", "2e01ee77-e9b5-5273-bf34-98f6a16f23d8", "for", "with a starting point"),
        ("B1_INIT-03", "135f730e-1a1a-563d-a542-751a8aab1321", "were", "I was reading"),
        ("B1_INT-01", "d011ed20-ee7e-5b09-83c1-e96576367973", "would", "possible future situation"),
        ("B1_INT-02", "2c42cd0c-dc31-5f77-a8a1-3629f588e5ee", "is", "novel was written"),
        ("B1_INT-03", "8457b852-e2d4-5aa3-9e26-cdbf8c29196e", "to read", "enjoy reading"),
        ("B1_ADV-01", "5790b56d-4019-51f4-8c29-a1136b2d0ddb", "are", "she was tired"),
        ("B1_ADV-02", "d04c9cab-5261-5610-8624-212b3010a4d2", "must", "something is impossible"),
        ("B1_ADV-03", "50d4f88f-f740-5fc8-bdf2-1f5fc31f8870", "take off", "stop trying"),
        ("B2_INIT-01", "16bda85a-06e8-564d-a9cc-605abd57a8b5", "wouldn't", "would have + past participle"),
        ("B2_INIT-02", "e3da1c02-dfad-5c50-aa8d-95e9ee6b45c0", "who's", "whose car was towed"),
        ("B2_INIT-03", "6ccea60d-e615-5881-82ca-88c30470b3ff", "live", "present situation were different"),
        ("B2_ADV-01", "7fdba315-0a9c-5c1c-b030-f24f9653efbe", "so boring", "such a boring film"),
        ("B2_ADV-02", "2bcd2270-53dd-544f-ac79-1198b03949e6", "do", "make a decision"),
        ("B2_ADV-03", "6b10323e-c394-5105-9dc9-baedd26d1849", "furthermore", "introduce contrast"),
        ("A1-04", "29a544a9-e0ae-5637-8d10-c5b72f7ed1da", "city", "city, cities"),
        ("A2_ADV-02", "27c2455e-3b94-54db-995c-6c36d74a355e", "some", "questions and negatives"),
        ("B1_INT-03", "c2cb17b0-4371-5713-974d-aa26e0d7d16b", "accepting", "decide to leave"),
        ("B1_ADV-01", "f67854fb-a621-5acb-b076-50e742935612", "will", "will** to **would"),
        ("B2_INIT-03", "1c164cc5-dc96-5c4c-b812-f86fe3f682b2", "didn't spend", "regret about a past situation"),
        ("B2_ADV-01", "66dc0973-460c-5bd1-8bfa-03a65190255a", "Although", "In spite of the rain"),
        ("B2_ADV-03", "dd63cb5c-9b7a-5424-9710-dd457e7c8304", "Although", "introduces a noun phrase")
    ]
}
