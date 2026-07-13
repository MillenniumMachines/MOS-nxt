#!/usr/bin/env node
/** Convert Vuetify 3 template patterns to Vuetify 2 for v0.6.0 backport panels. */
'use strict'
import fs from 'fs'
import path from 'path'

const files = process.argv.slice(2)
if (!files.length) {
  console.error('usage: node dist/vuetify3-to-2-vue.mjs file.vue ...')
  process.exit(1)
}

function convert(content) {
  let s = content
  s = s.replace(/v-expansion-panel-title/g, 'v-expansion-panel-header')
  s = s.replace(/v-expansion-panel-text/g, 'v-expansion-panel-content')
  s = s.replace(/:model-value=/g, ':value=')
  s = s.replace(/@update:model-value=/g, '@input=')
  s = s.replace(/\bdensity="compact"/g, 'dense')
  s = s.replace(/\bvariant="outlined"/g, 'outlined')
  s = s.replace(/\bvariant="flat"/g, 'depressed')
  s = s.replace(/\bvariant="tonal"/g, 'outlined')
  s = s.replace(/\bvariant="text"/g, 'text')
  s = s.replace(/\bsize="small"/g, 'small')
  s = s.replace(/\bitem-title=/g, 'item-text=')
  s = s.replace(/text-grey/g, 'grey--text')
  s = s.replace(/text-subtitle-2/g, 'subtitle-2')
  s = s.replace(/text-subtitle-1/g, 'subtitle-1')
  s = s.replace(/flex-wrap ga-2/g, 'flex-wrap')
  s = s.replace(/<v-card variant="outlined"/g, '<v-card outlined')
  s = s.replace(/<v-card outlined outlined/g, '<v-card outlined')
  s = s.replace(/from '\.\.\/\.\.\/compat\/dwcStore'/g, "from '@/store'")
  s = s.replace(/from "\.\.\/\.\.\/compat\/dwcStore"/g, 'from "@/store"')
  // v-icon: prefer left over class mr-2 where pattern is common
  s = s.replace(/<v-icon class="mr-2"/g, '<v-icon left')
  return s
}

for (const f of files) {
  const abs = path.resolve(f)
  const out = convert(fs.readFileSync(abs, 'utf8'))
  fs.writeFileSync(abs, out)
  console.log('converted', f)
}
