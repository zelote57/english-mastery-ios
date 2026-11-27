import Foundation
import Observation

@Observable
@MainActor
final class TestViewModel {
    let questions: [Question]
    let skill: Skill
    let inputController = QuestionInputController()
    private(set) var submissions: [QuestionSubmission] = []
    private(set) var currentIndex = 0
    private(set) var feedback = ""
    var showingFeedback = false
    var errorMessage: String?

    init(skill: Skill, questions: [Question], attempts: [Attempt]) {
        self.skill = skill
        let history = attempts.filter { $0.skillId == skill.id && $0.attemptType == .skillAssessment }
        let answered = Set(history.flatMap(\.answers).map(\.questionId))
        let missed = Set(history.flatMap(\.answers).filter { $0.pointsEarned == 0 }.map(\.questionId))
        let bank = questions.filter { $0.skillId == skill.id }.shuffled()
        let priority = bank.filter { !answered.contains($0.id) || missed.contains($0.id) }
        let rest = bank.filter { answered.contains($0.id) && !missed.contains($0.id) }
        self.questions = Array((priority + rest).prefix(15))
        if self.questions.count < 15 {
            errorMessage = "This skill does not have enough questions for an assessment."
        } else if let first = self.questions.first {
            inputController.load(question: first)
        }
    }

    var currentQuestion: Question? {
        questions.indices.contains(currentIndex) ? questions[currentIndex] : nil
    }

    func submit(onComplete: ([QuestionSubmission]) throws -> Void) {
        guard questions.count == 15, let question = currentQuestion, inputController.canSubmit,
              submissions.count == currentIndex, !showingFeedback else { return }
        let answer = inputController.currentAnswerString
        let grade = ScoringEngine.grade(answer: answer, for: question)
        let explanation = grade.pointsEarned == 0 ? Self.fallback(skill: skill, question: question, answer: answer) : nil
        submissions.append(QuestionSubmission(question: question, userAnswer: answer, ragFeedback: explanation))
        if let explanation {
            feedback = explanation
            showingFeedback = true
        } else {
            advance(onComplete: onComplete)
        }
    }

    func advance(onComplete: ([QuestionSubmission]) throws -> Void) {
        guard submissions.count == currentIndex + 1 else { return }
        showingFeedback = false
        if submissions.count == questions.count {
            do {
                try onComplete(submissions)
                errorMessage = nil
            } catch {
                errorMessage = "Unable to save this assessment. Please try again."
            }
        } else {
            currentIndex += 1
            inputController.load(question: questions[currentIndex])
        }
    }

    private static func fallback(skill: Skill, question: Question, answer: String) -> String {
        let rules: [String: String] = [
            "A1-01": "Elige el pronombre que corresponde a la persona o cosa de la oración.",
            "A1-02": "El verbo to be cambia según el sujeto: I am, you are, he is.",
            "A1-03": "Usa a o an para algo singular no específico y the para algo específico.",
            "A1-04": "El plural regular suele formarse con -s o -es.",
            "A1-05": "En presente simple, añade -s o -es al verbo con he, she o it.",
            "A2_INIT-01": "El pasado de los verbos regulares suele terminar en -ed.",
            "A2_INIT-02": "Los verbos irregulares tienen formas de pasado que debes aprender.",
            "A2_INIT-03": "Usa expresiones como yesterday o last week para situar una acción en el pasado.",
            "A2_INT-01": "Usa una forma de to be seguida de going to y el verbo base para expresar planes.",
            "A2_INT-02": "Usa will seguido del verbo base para expresar futuro.",
            "A2_INT-03": "Usa el comparativo para comparar dos elementos y el superlativo para destacar uno dentro de un grupo.",
            "A2_ADV-01": "Elige in, on o at según la expresión de lugar o tiempo.",
            "A2_ADV-02": "Elige el cuantificador según si el sustantivo es contable o incontable.",
            "A2_ADV-03": "Después de can y could usa el verbo base; have to también va seguido del verbo base.",
            "B1_INIT-01": "El present perfect se forma con have o has y el participio pasado.",
            "B1_INIT-02": "Usa for para una duración y since para el momento de inicio.",
            "B1_INIT-03": "El past continuous se forma con was o were y el verbo terminado en -ing.",
            "B1_INT-01": "El primer condicional expresa una posibilidad; el segundo plantea una situación hipotética.",
            "B1_INT-02": "La voz pasiva se forma con to be y el participio pasado.",
            "B1_INT-03": "Algunos verbos van seguidos de -ing y otros de to más infinitivo.",
            "B1_ADV-01": "En estilo indirecto, ajusta los tiempos y pronombres al comunicar lo que alguien dijo.",
            "B1_ADV-02": "Elige el verbo modal según expreses deducción, posibilidad o consejo.",
            "B1_ADV-03": "Un phrasal verb combina un verbo con una partícula y puede tener un significado propio.",
            "B2_INIT-01": "El tercer condicional habla de una situación pasada hipotética y su resultado.",
            "B2_INIT-02": "Elige el pronombre relativo adecuado y usa comas en las relativas explicativas.",
            "B2_INIT-03": "Wish e if only expresan deseos o situaciones que quisiéramos distintas.",
            "B2_ADV-01": "Conserva el significado original al transformar la frase con la palabra indicada.",
            "B2_ADV-02": "Una colocación combina palabras que suelen usarse juntas, como make a decision.",
            "B2_ADV-03": "Elige el conector según la relación entre las ideas, como contraste o consecuencia."
        ]
        let rule = rules[skill.skillCode] ?? "Compara las palabras y su orden con la respuesta esperada."
        return """
        ### 💡 ¿Por qué no es correcta?
        Tu respuesta no coincide con la respuesta esperada para esta pregunta.

        ### 📘 Regla clave
        \(rule)

        ### 🔍 Ejemplos prácticos
        - ❌ Tu respuesta: \(answer)
        - ✅ Respuesta esperada: \(question.correctAnswer)
        """
    }
}
