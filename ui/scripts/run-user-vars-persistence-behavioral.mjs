/**
 * Invoked by run-user-vars-persistence-tests.mjs via npx tsx.
 * Loads the TypeScript suite and exits non-zero on failure.
 */
import { runAllNxtUserVarsPersistenceTests } from '../src/utils/nxtUserVarsPersistence.spec.ts'

try {
  runAllNxtUserVarsPersistenceTests()
  console.log('nxtUserVarsPersistence behavioral tests passed')
} catch (e) {
  console.error(e)
  process.exit(1)
}
