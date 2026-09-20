/*
Copyright (C) 2023-2026 QuantumNous

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU Affero General Public License as
published by the Free Software Foundation, either version 3 of the
License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
GNU Affero General Public License for more details.

You should have received a copy of the GNU Affero General Public License
along with this program. If not, see <https://www.gnu.org/licenses/>.

For commercial licensing, please contact support@quantumnous.com
*/
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import {
  createMemoryHistory,
  createRootRoute,
  createRouter,
  RouterProvider,
} from '@tanstack/react-router'
import { cleanup, render, screen } from '@testing-library/react'
import { afterEach, expect, test } from 'vitest'

import { STATUS_QUERY_KEY } from '@/lib/status-query'
import { useSystemConfigStore } from '@/stores/system-config-store'

import { SystemBrand } from '../system-brand'

const version = 'v1.0.0-rc.36'

afterEach(() => {
  cleanup()
  useSystemConfigStore.setState(useSystemConfigStore.getInitialState(), true)
})

test('renders the header brand name without a version label', async () => {
  const client = new QueryClient({
    defaultOptions: { queries: { retry: false, staleTime: Infinity } },
  })
  client.setQueryData(STATUS_QUERY_KEY, {
    system_name: 'Token Up',
    version,
  })
  const root = createRootRoute({
    component: function Root() {
      return (
        <QueryClientProvider client={client}>
          <SystemBrand variant='inline' />
        </QueryClientProvider>
      )
    },
  })
  const router = createRouter({
    routeTree: root,
    history: createMemoryHistory({ initialEntries: ['/'] }),
  })
  render(<RouterProvider router={router} />)
  expect(await screen.findByText('Token Up')).toBeInTheDocument()
  expect(screen.queryByText(version)).not.toBeInTheDocument()
  expect(screen.queryByText('Unknown version')).not.toBeInTheDocument()
})
