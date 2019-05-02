<?php
declare(strict_types=1);

/**
 * This file is part of the Phalcon Framework.
 *
 * (c) Phalcon Team <team@phalconphp.com>
 *
 * For the full copyright and license information, please view the LICENSE.txt
 * file that was distributed with this source code.
 */

namespace Phalcon\Test\Integration\Mvc\Model;

use IntegrationTester;
use Phalcon\Test\Fixtures\Traits\DiTrait;
use Phalcon\Test\Models\Users;

/**
 * Class WriteAttributeCest
 */
class WriteAttributeCest
{
    use DiTrait;

    public function _before(IntegrationTester $I)
    {
        $this->setNewFactoryDefault();
        $this->setDiMysql();
    }

    /**
     * Tests Phalcon\Mvc\Model :: writeAttribute()
     *
     * @param IntegrationTester $I
     *
     * @author Sid Roberts <sid@sidroberts.co.uk>
     * @since  2019-04-18
     */
    public function mvcModelWriteAttribute(IntegrationTester $I)
    {
        $I->wantToTest('Mvc\Model - writeAttribute()');

        $user = new Users();

        $user->writeAttribute('id', 123);
        $user->writeAttribute('name', 'Sid');

        $I->assertEquals(
            123,
            $user->readAttribute('id')
        );

        $I->assertEquals(
            'Sid',
            $user->readAttribute('name')
        );

        $I->assertEquals(
            [
                'id'   => 123,
                'name' => 'Sid',
            ],
            $user->toArray()
        );
    }

    /**
     * Tests Phalcon\Mvc\Model :: writeAttribute() with associative array
     *
     * @param IntegrationTester $I
     *
     * @author Balázs Németh <https://github.com/zsilbi>
     * @since  2019-04-30
     */
    public function mvcModelWriteAttributeWithAssociativeArray(IntegrationTester $I)
    {
        $I->wantToTest('Tests Phalcon\Mvc\Model :: writeAttribute() with associative array');

        $associativeArray = [
            'firstName' => 'First name',
            'lastName' => 'Last name'
        ];

        $user = new Users();
        $user->writeAttribute('id', 123);
        $user->writeAttribute('name', $associativeArray);

        $I->assertEquals(
            $associativeArray,
            $user->readAttribute('name')
        );

        $I->assertEquals(
            [
                'id'   => 123,
                'name' => $associativeArray
            ],
            $user->toArray()
        );
    }

    /**
     * Tests Phalcon\Mvc\Model :: writeAttribute() undefined property with associative array
     *
     * @param IntegrationTester $I
     *
     * @see https://github.com/phalcon/cphalcon/issues/14021
     *
     * @author Balázs Németh <https://github.com/zsilbi>
     * @since  2019-04-30
     */
    public function mvcModelWriteAttributeUndefinedPropertyWithAssociativeArray(IntegrationTester $I)
    {
        $I->wantToTest('Tests Phalcon\Mvc\Model :: writeAttribute() undefined property with associative array');

        $associativeArray = [
            'id' => 123,
            'name' => 'My Name'
        ];

        $user = new Users();
        $user->whatEverUndefinedProperty = $associativeArray;

        $I->assertEquals(
            [
                'id'   => null,
                'name' => null
            ],
            $user->toArray()
        );
    }
}
