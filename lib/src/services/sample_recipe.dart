import '../models/recipe.dart';

/// The example recipe seeded into brand-new accounts so people see how
/// recipes work: sections, ordered steps, techniques, links — and that it can
/// be edited, shared or simply deleted.
///
/// A simplified Necron scheme contributed by a veteran painter. Every paintId
/// MUST exist in the bundled catalog — test/sample_recipe_test.dart enforces
/// it.
Recipe buildSampleRecipe(String languageCode) {
  final spanish = languageCode == 'es';

  return Recipe(
    id: '',
    name: spanish ? 'Ejemplo: Lord Necrón' : 'Example: Necron Lord',
    description: spanish
        ? 'Una receta de ejemplo para que veas cómo funcionan: pasos ordenados '
            'por sección, técnicas y enlaces. Edítala, compártela con el icono '
            'de compartir (quien la vincule verá siempre tu última versión) o '
            'bórrala sin miedo.'
        : 'An example recipe so you can see how they work: ordered steps per '
            'section, techniques and links. Edit it, share it with the share '
            'icon (anyone who links it always sees your latest version) or '
            'just delete it.',
    sections: [
      RecipeSection(
        name: spanish ? 'Armadura / cuerpo' : 'Armour / body',
        techniques: const {PaintTechnique.drybrush, PaintTechnique.wash},
        steps: [
          RecipeStep(
            title: spanish ? 'Base' : 'Basecoat',
            paintId: 'citadel-leadbelcher',
            note: spanish
                ? 'Pincel seco generoso por toda la figura'
                : 'Generous drybrush over the whole model',
          ),
          RecipeStep(
            title: spanish ? 'Sombra' : 'Wash',
            paintId: 'citadel-agrax-earthshade',
            note: spanish
                ? 'Tintado en huecos y juntas'
                : 'Into recesses and joints',
          ),
          RecipeStep(
            title: spanish ? 'Primera luz' : 'First highlight',
            paintId: 'citadel-leadbelcher',
            note: spanish
                ? 'Pincel seco suave solo en aristas'
                : 'Light drybrush on edges only',
          ),
        ],
      ),
      RecipeSection(
        name: spanish ? 'Dorados / ornamentos' : 'Gold trim / ornaments',
        techniques: const {PaintTechnique.layering, PaintTechnique.highlight},
        steps: [
          RecipeStep(
            title: spanish ? 'Base' : 'Basecoat',
            paintId: 'citadel-retributor-armour',
          ),
          RecipeStep(
            title: spanish ? 'Sombra' : 'Wash',
            paintId: 'citadel-agrax-earthshade',
          ),
          RecipeStep(
            title: 'Edge highlight',
            paintId: 'citadel-liberator-gold',
          ),
        ],
      ),
      RecipeSection(
        name: spanish ? 'Energía verde (arma)' : 'Green energy (weapon)',
        techniques: const {PaintTechnique.layering, PaintTechnique.glaze},
        steps: [
          RecipeStep(
            title: spanish ? 'Base' : 'Basecoat',
            paintId: 'citadel-caliban-green',
          ),
          RecipeStep(
            title: spanish ? 'Capa' : 'Layer',
            paintId: 'citadel-warpstone-glow',
          ),
          RecipeStep(
            title: spanish ? 'Luz' : 'Highlight',
            paintId: 'citadel-moot-green',
          ),
          RecipeStep(
            title: spanish ? 'Punto máximo' : 'Spot highlight',
            paintId: 'citadel-white-scar',
            note: spanish ? 'Solo puntos de máxima luz' : 'Hottest points only',
          ),
        ],
      ),
      RecipeSection(
        name: spanish ? 'Gemas verdes' : 'Green gems',
        techniques: const {PaintTechnique.layering},
        steps: [
          RecipeStep(
            title: spanish ? 'Base' : 'Basecoat',
            paintId: 'citadel-caliban-green',
          ),
          RecipeStep(
            title: spanish ? 'Sombra' : 'Shade',
            paintId: 'citadel-abaddon-black',
            note: spanish ? 'Muy diluido' : 'Heavily thinned',
          ),
          RecipeStep(
            title: spanish ? 'Primera luz' : 'First highlight',
            paintId: 'citadel-sybarite-green',
          ),
          RecipeStep(
            title: spanish ? 'Punto blanco' : 'White dot',
            paintId: 'citadel-white-scar',
          ),
        ],
      ),
      RecipeSection(
        name: spanish ? 'Peana' : 'Base',
        techniques: const {PaintTechnique.drybrush, PaintTechnique.wash},
        steps: [
          RecipeStep(
            title: spanish ? 'Base' : 'Basecoat',
            paintId: 'citadel-mechanicus-standard-grey',
          ),
          RecipeStep(
            title: spanish ? 'Sombra' : 'Wash',
            paintId: 'citadel-agrax-earthshade',
          ),
        ],
      ),
    ],
    links: [
      RecipeLink(
        title: spanish
            ? 'Cómo pintar gemas (vídeo)'
            : 'How to paint gems (video)',
        url: 'https://www.youtube.com/watch?v=zKnxFtGH-L0',
      ),
    ],
    updatedAt: DateTime.now(),
  );
}
