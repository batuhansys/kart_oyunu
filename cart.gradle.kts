// Card.kt
import java.util.UUID

data class Card(
    val id: String,
    val name: String,
    val power: Int,
    val type: String, // "attack", "defense", "utility"
    val ability: String,
    val bluffValue: Int? = null,
    val instanceId: String = UUID.randomUUID().toString() // Sahadaki aynı kartları ayırt etmek için
)