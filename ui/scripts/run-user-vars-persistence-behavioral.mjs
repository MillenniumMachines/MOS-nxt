/**
 * Invoked by run-user-vars-persistence-tests.mjs via npx tsx.
 * Loads the TypeScript suite and exits non-zero on failure.
 */
import { runAllNxtUserVarsPersistenceTests } from '../src/utils/nxtUserVarsPersistence.spec.ts'
import { runAllNxtOperatorFacesTests } from '../src/utils/nxtOperatorFaces.spec.ts'

try {
  runAllNxtUserVarsPersistenceTests()
  runAllNxtOperatorFacesTests()
  console.log('nxtUserVarsPersistence behavioral tests passed')
} catch (e) {
  console.error(e)
  process.exit(1)
}
